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
    case exportCSV = 0x03
    case response = 0x80
    case error = 0x81
}

/// IPC message structure for Swift-NIO
struct IPCMessage {
    static let currentVersion: UInt8 = 2

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
        // Need at least 6 bytes for header: [version:1][type:1][length:4]
        guard buffer.readableBytes >= 6 else {
            return .needMoreData
        }

        let readerIndex = buffer.readerIndex
        guard let version = buffer.readInteger(as: UInt8.self),
            let typeRaw = buffer.readInteger(as: UInt8.self),
            let bodyLength = buffer.readInteger(endianness: .big, as: UInt32.self),
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
        out.writeInteger(UInt32(data.body.count), endianness: .big)
        out.writeBytes(data.body)
    }
}

/// Swift-NIO client for communicating with SimplyTrack main app
actor IPCClient {
    private let socketPath: String
    private static let requestTimeout: TimeAmount = .seconds(10)
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

        try appendShortString(dateString ?? "", to: &body)
        try appendShortString(typeFilter, to: &body)

        return try await sendMessage(type: .getUsageActivity, body: body)
    }

    /// Export day or week usage data from the main app as CSV.
    func exportCSV(dateString: String?, period: String) async throws -> String? {
        var body = Data()

        try appendShortString(dateString ?? "", to: &body)
        try appendShortString(period, to: &body)

        return try await sendMessage(type: .exportCSV, body: body)
    }

    private func appendShortString(_ string: String, to body: inout Data) throws {
        let data = string.data(using: .utf8) ?? Data()
        guard data.count <= UInt8.max else {
            throw NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "IPC string parameter is too long"])
        }

        body.append(UInt8(data.count))
        body.append(data)
    }

    /// Send message to Swift-NIO server and wait for response
    private func sendMessage(type: MessageType, body: Data) async throws -> String? {
        let clientSocketPath = self.socketPath  // Capture socket path before closure

        return try await withCheckedThrowingContinuation { continuation in
            let responseState = IPCResponseState(continuation: continuation)
            let timeoutTask = eventLoopGroup.next().scheduleTask(in: Self.requestTimeout) {
                let timeoutError = NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "IPC request timed out after 10 seconds"])
                responseState.fail(timeoutError, closeChannel: true)
            }
            responseState.setTimeoutTask(timeoutTask)

            let bootstrap = ClientBootstrap(group: eventLoopGroup)
                .channelOption(.socketOption(.so_reuseaddr), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers([
                        ByteToMessageHandler(IPCProtocolCodec()) as ChannelHandler,
                        MessageToByteHandler(IPCProtocolCodec()) as ChannelHandler,
                        IPCClientHandler(responseState: responseState),
                    ])
                }

            // Connect to Unix domain socket
            bootstrap.connect(unixDomainSocketPath: clientSocketPath).whenComplete { result in
                switch result {
                case .success(let channel):
                    guard responseState.setChannel(channel) else { return }

                    // Create request message
                    let requestMessage = IPCMessage(type: type, body: body)

                    // Send request
                    channel.writeAndFlush(requestMessage).whenComplete { writeResult in
                        switch writeResult {
                        case .success:
                            // Message sent successfully, response will be handled by IPCClientHandler
                            break
                        case .failure(let error):
                            responseState.fail(error, closeChannel: true)
                        }
                    }
                case .failure(let error):
                    let errorMessage: String
                    if error.localizedDescription.contains("Connection refused") || error.localizedDescription.contains("No such file") {
                        errorMessage = "Cannot connect to SimplyTrack app at \(clientSocketPath). Please ensure SimplyTrack is running and the IPC server is enabled."
                    } else {
                        errorMessage = "Connection failed: \(error.localizedDescription). Is SimplyTrack app running?"
                    }
                    responseState.fail(NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]), closeChannel: false)
                }
            }

        }
    }
}

// MARK: - Client Response State

private final class IPCResponseState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Error>?
    private var channel: Channel?
    private var timeoutTask: Scheduled<Void>?

    init(continuation: CheckedContinuation<String?, Error>) {
        self.continuation = continuation
    }

    func setChannel(_ channel: Channel) -> Bool {
        lock.lock()
        guard continuation != nil else {
            lock.unlock()
            channel.close(promise: nil)
            return false
        }
        self.channel = channel
        lock.unlock()
        return true
    }

    func setTimeoutTask(_ task: Scheduled<Void>) {
        lock.lock()
        guard continuation != nil else {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    func succeed(_ value: String?) {
        complete(.success(value), closeChannel: true)
    }

    func fail(_ error: Error, closeChannel: Bool) {
        complete(.failure(error), closeChannel: closeChannel)
    }

    private func complete(_ result: Result<String?, Error>, closeChannel: Bool) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }

        self.continuation = nil
        let channelToClose = closeChannel ? channel : nil
        channel = nil
        let timeoutTaskToCancel = timeoutTask
        timeoutTask = nil
        lock.unlock()

        timeoutTaskToCancel?.cancel()
        channelToClose?.close(promise: nil)

        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - Client Channel Handler

/// Channel handler for handling IPC responses on the client side
private final class IPCClientHandler: ChannelInboundHandler {
    typealias InboundIn = IPCMessage

    private let responseState: IPCResponseState

    init(responseState: IPCResponseState) {
        self.responseState = responseState
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = unwrapInboundIn(data)

        // Check version compatibility
        guard message.version == IPCMessage.currentVersion else {
            responseState.fail(
                NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Version mismatch: server=\(message.version), client=\(IPCMessage.currentVersion)"]),
                closeChannel: true
            )
            return
        }

        // Handle response
        switch message.type {
        case .error:
            let errorMessage = String(data: message.body, encoding: .utf8) ?? "Unknown error"
            responseState.fail(NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]), closeChannel: true)
        case .response:
            responseState.succeed(String(data: message.body, encoding: .utf8))
        default:
            responseState.fail(NSError(domain: "IPCClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response type"]), closeChannel: true)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        responseState.fail(error, closeChannel: true)
    }
}
