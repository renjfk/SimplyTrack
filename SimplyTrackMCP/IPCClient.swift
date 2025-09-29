//
//  IPCClient.swift
//  SimplyTrackMCP
//
//  Created by Soner Köksal on 27.09.2025.
//

import Foundation
import NIOCore
import NIOPosix

// MARK: - IPC Message Types

enum MessageType: UInt8 {
    case getVersion = 0x01
    case getUsageActivity = 0x02
    case response = 0x80
    case error = 0x81
}

/// IPC message structure for Swift-NIO
struct IPCMessage {
    static let currentVersion: UInt8 = 1

    let version: UInt8
    let type: MessageType
    let body: Data

    init(version: UInt8 = currentVersion, type: MessageType, body: Data) {
        self.version = version
        self.type = type
        self.body = body
    }
}

/// IPC message encoder/decoder for Swift-NIO
private final class IPCProtocolCodec: ByteToMessageDecoder, MessageToByteEncoder {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = IPCMessage
    typealias OutboundIn = IPCMessage
    typealias OutboundOut = ByteBuffer

    init() {}

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Need at least 4 bytes for header: [version:1][type:1][length:2]
        guard buffer.readableBytes >= 4 else {
            return .needMoreData
        }

        let readerIndex = buffer.readerIndex
        guard let version = buffer.readInteger(as: UInt8.self),
            let typeRaw = buffer.readInteger(as: UInt8.self),
            let bodyLength = buffer.readInteger(endianness: .big, as: UInt16.self),
            let type = MessageType(rawValue: typeRaw)
        else {
            buffer.moveReaderIndex(to: readerIndex)  // Reset on error
            throw NSError(domain: "IPCProtocolCodec", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid header"])
        }

        // Check if we have enough bytes for the complete message
        guard buffer.readableBytes >= Int(bodyLength) else {
            buffer.moveReaderIndex(to: readerIndex)  // Reset and wait for more data
            return .needMoreData
        }

        // Read the body
        let body: Data
        if let bodySlice = buffer.readSlice(length: Int(bodyLength)) {
            body =
                bodySlice.readableBytesView.withContiguousStorageIfAvailable { bytes in
                    Data(bytes)
                } ?? Data()
        } else {
            body = Data()
        }

        let message = IPCMessage(version: version, type: type, body: body)
        context.fireChannelRead(Self.wrapInboundOut(message))
        return .continue
    }

    func encode(data: IPCMessage, out: inout ByteBuffer) throws {
        out.writeInteger(data.version)
        out.writeInteger(data.type.rawValue)
        out.writeInteger(UInt16(data.body.count), endianness: .big)
        out.writeBytes(data.body)
    }
}

/// Swift-NIO client for communicating with SimplyTrack main app
actor IPCClient {
    private let socketPath: String
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    /// Get version from the main SimplyTrack app
    func getVersion() async throws -> String {
        return try await sendMessage(type: .getVersion, body: Data()) ?? "Unknown"
    }

    /// Get usage activity data from the main app
    func getUsageActivity(topPercentage: Double, dateString: String?, typeFilter: String) async throws -> String? {
        // Serialize parameters: [topPercentage:8][dateStringLength:1][dateString][typeFilterLength:1][typeFilter]
        var body = Data()

        // Add topPercentage as double (8 bytes, big endian)
        let topPercentageBits = topPercentage.bitPattern.bigEndian
        body.append(contentsOf: withUnsafeBytes(of: topPercentageBits) { Array($0) })

        // Add dateString (length + string)
        if let dateString = dateString {
            let dateData = dateString.data(using: .utf8) ?? Data()
            body.append(UInt8(dateData.count))
            body.append(dateData)
        } else {
            body.append(UInt8(0))
        }

        // Add typeFilter (length + string)
        let typeFilterData = typeFilter.data(using: .utf8) ?? Data()
        body.append(UInt8(typeFilterData.count))
        body.append(typeFilterData)

        return try await sendMessage(type: .getUsageActivity, body: body)
    }

    /// Send message to Swift-NIO server and wait for response
    private func sendMessage(type: MessageType, body: Data) async throws -> String? {
        let clientSocketPath = self.socketPath  // Capture socket path before closure

        return try await withCheckedThrowingContinuation { continuation in
            let bootstrap = ClientBootstrap(group: eventLoopGroup)
                .channelOption(.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers([
                        ByteToMessageHandler(IPCProtocolCodec()) as ChannelHandler,
                        MessageToByteHandler(IPCProtocolCodec()) as ChannelHandler,
                        IPCClientHandler(continuation: continuation),
                    ])
                }

            // Connect to Unix domain socket
            bootstrap.connect(unixDomainSocketPath: clientSocketPath).whenComplete { result in
                switch result {
                case .success(let channel):
                    // Create request message
                    let requestMessage = IPCMessage(type: type, body: body)

                    // Send request
                    channel.writeAndFlush(requestMessage).whenComplete { writeResult in
                        switch writeResult {
                        case .success:
                            // Message sent successfully, response will be handled by IPCClientHandler
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                            _ = channel.close()
                        }
                    }
                case .failure(let error):
                    let errorMessage: String
                    if error.localizedDescription.contains("Connection refused") || error.localizedDescription.contains("No such file") {
                        errorMessage = "Cannot connect to SimplyTrack app at \(clientSocketPath). Please ensure SimplyTrack is running and the IPC server is enabled."
                    } else {
                        errorMessage = "Connection failed: \(error.localizedDescription). Is SimplyTrack app running?"
                    }
                    continuation.resume(
                        throwing: NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    )
                }
            }

        }
    }
}

// MARK: - Client Channel Handler

/// Channel handler for handling IPC responses on the client side
private final class IPCClientHandler: ChannelInboundHandler {
    typealias InboundIn = IPCMessage

    private let continuation: CheckedContinuation<String?, Error>
    private var hasResponded = false

    init(continuation: CheckedContinuation<String?, Error>) {
        self.continuation = continuation
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard !hasResponded else { return }
        hasResponded = true

        let message = unwrapInboundIn(data)

        // Check version compatibility
        guard message.version == IPCMessage.currentVersion else {
            continuation.resume(
                throwing: NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Version mismatch: server=\(message.version), client=\(IPCMessage.currentVersion)"])
            )
            context.close(promise: nil)
            return
        }

        // Handle response
        switch message.type {
        case .error:
            let errorMessage = String(data: message.body, encoding: .utf8) ?? "Unknown error"
            continuation.resume(throwing: NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        case .response:
            continuation.resume(returning: String(data: message.body, encoding: .utf8))
        default:
            continuation.resume(throwing: NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type"]))
        }

        context.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if !hasResponded {
            hasResponded = true
            continuation.resume(throwing: error)
        }
        context.close(promise: nil)
    }
}
