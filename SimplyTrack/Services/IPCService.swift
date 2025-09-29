//
//  IPCService.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 22.09.2025.
//

import Foundation
import NIOCore
import NIOPosix
import SwiftData
import os

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

/// IPC service implementation for communicating with CLI via Unix domain sockets
class IPCService: NSObject, @unchecked Sendable {
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "IPCService")
    private let modelContainer: ModelContainer

    /// Retrieves aggregated usage activity data for a specific date and type
    ///
    /// This method fetches usage statistics from the SwiftData store, aggregates the data
    /// according to the specified parameters, and returns a formatted string suitable for
    /// MCP tool consumption.
    ///
    /// - Parameters:
    ///   - topPercentage: Percentage of top activities to include (0.0-1.0).
    ///                   For example, 0.8 includes the top 80% most-used activities.
    ///   - dateString: Target date in "yyyy-MM-dd" format, or nil to use current date.
    ///   - typeFilter: Filter by usage type. Valid values: "app", "website".
    ///   - completion: Completion handler called with results
    ///     - result: Formatted usage data string, or nil if no data found
    ///     - error: Error if data retrieval failed, nil on success
    ///
    /// ## Output Format
    /// Returns a pipe-separated string: `name:duration|name:duration|...|Total:duration`
    /// - Example: `"Xcode:3h45m|Safari:2h18m|Terminal:1h20m|Total:7h23m"`
    func getUsageActivity(topPercentage: Double, dateString: String?, typeFilter: String, completion: @escaping (String?, Error?) -> Void) {
        do {
            let context = ModelContext(modelContainer)

            // Parse date or use today
            let targetDate: Date
            if let dateString = dateString {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                targetDate = formatter.date(from: dateString) ?? Date()
            } else {
                targetDate = Date()
            }

            // Convert string to UsageType
            let usageType = UsageType(rawValue: typeFilter) ?? .app

            // Get aggregator output
            let usage = try UsageAggregator.aggregateUsage(
                for: targetDate,
                type: usageType,
                topPercentage: topPercentage,
                modelContext: context
            )

            completion(usage.isEmpty ? nil : usage, nil)
        } catch {
            logger.error("Failed to fetch usage activity: \(error.localizedDescription)")
            completion(nil, error)
        }
    }

    /// Retrieves the current version of the SimplyTrack application
    ///
    /// This method returns the app's version string from the main bundle.
    /// It also serves as a connectivity check - if this method succeeds,
    /// it indicates the main app is running and IPC communication is working.
    ///
    /// - Parameter completion: Completion handler called with the version string
    ///   - version: Current app version (e.g., "1.2.3"), never nil
    func getVersion(completion: @escaping (String) -> Void) {
        Task { @MainActor in
            let version = UpdateManager.shared.getCurrentVersion()
            completion(version)
        }
    }
}

/// Swift-NIO service manager for handling IPC connections via Unix domain sockets
class IPCServiceManager: NSObject, @unchecked Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "IPCServiceManager"
    )
    private var isRunning = false

    private nonisolated let service: IPCService
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var serverChannel: Channel?

    /// Static socket path for Unix domain socket IPC
    nonisolated static var socketPath: String {
        let tempDir = FileManager.default.temporaryDirectory
        #if DEBUG
            return tempDir.appendingPathComponent("ipc.debug.sock").path
        #else
            return tempDir.appendingPathComponent("ipc.sock").path
        #endif
    }

    init(modelContainer: ModelContainer) {
        self.service = IPCService(modelContainer: modelContainer)
        super.init()
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    /// Starts the IPC service for communication with MCP clients using Swift-NIO
    ///
    /// This method creates a Unix domain socket server that allows MCP clients to communicate
    /// with the main app using binary protocol messages.
    ///
    /// The service handles:
    /// - Creating Unix domain socket listener using Swift-NIO
    /// - Accepting client connections
    /// - Processing binary protocol messages with custom codec
    /// - Concurrent client support
    ///
    /// Safe to call multiple times - will not create duplicate services.
    func startService() {
        guard !isRunning else {
            logger.info("IPC service already running")
            return
        }

        Task {
            do {
                try FileManager.default.removeItem(atPath: Self.socketPath)

                // Capture service and manager before the closure to avoid Sendable issues
                let service = self.service
                let manager = self

                let bootstrap = ServerBootstrap(group: eventLoopGroup)
                    .serverChannelOption(.backlog, value: 256)
                    .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
                    .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
                    .childChannelOption(.maxMessagesPerRead, value: 16)
                    .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
                    .childChannelInitializer { channel in
                        channel.pipeline.addHandlers([
                            ByteToMessageHandler(IPCProtocolCodec()) as ChannelHandler,
                            MessageToByteHandler(IPCProtocolCodec()) as ChannelHandler,
                            IPCChannelHandler(service: service, manager: manager),
                        ])
                    }

                // Use Unix domain socket
                let channel = try await bootstrap.bind(unixDomainSocketPath: Self.socketPath).get()

                self.serverChannel = channel
                self.isRunning = true
                self.logger.info("Swift-NIO Unix domain socket IPC service started at \(Self.socketPath)")

                try await channel.closeFuture.get()

            } catch {
                self.logger.error("Failed to start Swift-NIO Unix socket service: \(error.localizedDescription)")
                self.isRunning = false
            }
        }
    }

    /// Stops the Swift-NIO IPC service and cleans up resources
    ///
    /// This method gracefully shuts down the listener and cancels all connections.
    /// Safe to call multiple times or when service is not running.
    func stopService() {
        Task {
            do {
                try await serverChannel?.close()
            } catch {
                logger.error("Error closing server channel: \(error.localizedDescription)")
            }
            serverChannel = nil

            // Clean up Unix socket file
            try? FileManager.default.removeItem(atPath: Self.socketPath)

            // Clear environment variable
            unsetenv("SIMPLYTRACK_SOCKET_PATH")

            self.isRunning = false
            self.logger.info("Swift-NIO IPC service stopped")
        }
    }
}

// MARK: - Swift-NIO Channel Handler

/// Channel handler for processing IPC messages using Swift-NIO
private final class IPCChannelHandler: ChannelInboundHandler {
    typealias InboundIn = IPCMessage
    typealias OutboundOut = IPCMessage

    private let service: IPCService
    private weak var manager: IPCServiceManager?

    init(service: IPCService, manager: IPCServiceManager) {
        self.service = service
        self.manager = manager
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = unwrapInboundIn(data)

        // Version compatibility check
        guard message.version == IPCMessage.currentVersion else {
            let errorResponse = IPCMessage(type: .error, body: "Version mismatch: client=\(message.version), server=\(IPCMessage.currentVersion)".data(using: .utf8) ?? Data())
            context.writeAndFlush(wrapOutboundOut(errorResponse), promise: nil)
            return
        }

        // Create a promise for the response
        let promise = context.eventLoop.makePromise(of: IPCMessage.self)

        // Process message asynchronously
        Task {
            // Process based on message type
            let response: IPCMessage
            switch message.type {
            case .getUsageActivity:
                response = await handleGetUsageActivity(body: message.body)
            case .getVersion:
                response = await handleGetVersion()
            default:
                response = IPCMessage(type: .error, body: "Unknown message type: \(message.type.rawValue)".data(using: .utf8) ?? Data())
            }
            promise.succeed(response)
        }

        // When promise completes, write the response (this happens on EventLoop)
        promise.futureResult.whenComplete { result in
            switch result {
            case .success(let response):
                context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
            case .failure(let error):
                let errorResponse = IPCMessage(type: .error, body: "Internal error: \(error.localizedDescription)".data(using: .utf8) ?? Data())
                context.writeAndFlush(self.wrapOutboundOut(errorResponse), promise: nil)
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("IPC Channel error: \(error)")
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        context.close(promise: nil)
    }

    private func handleGetUsageActivity(body: Data) async -> IPCMessage {
        // Parse parameters from body: [topPercentage:8][dateStringLength:1][dateString][typeFilterLength:1][typeFilter]
        var offset = 0
        guard body.count >= 8 else {
            return IPCMessage(type: .error, body: "Invalid getUsageActivity parameters".data(using: .utf8) ?? Data())
        }

        let topPercentage = body.subdata(in: offset..<offset + 8).withUnsafeBytes { $0.load(as: Double.self).bitPattern.bigEndian }
        offset += 8

        guard offset < body.count else {
            return IPCMessage(type: .error, body: "Invalid getUsageActivity parameters".data(using: .utf8) ?? Data())
        }

        let dateStringLength = Int(body[offset])
        offset += 1

        var dateString: String?
        if dateStringLength > 0 {
            guard offset + dateStringLength <= body.count else {
                return IPCMessage(type: .error, body: "Invalid getUsageActivity parameters".data(using: .utf8) ?? Data())
            }
            dateString = String(data: body.subdata(in: offset..<offset + dateStringLength), encoding: .utf8)
            offset += dateStringLength
        }

        guard offset < body.count else {
            return IPCMessage(type: .error, body: "Invalid getUsageActivity parameters".data(using: .utf8) ?? Data())
        }

        let typeFilterLength = Int(body[offset])
        offset += 1

        var typeFilter = "app"
        if typeFilterLength > 0, offset + typeFilterLength <= body.count {
            if let parsedTypeFilter = String(data: body.subdata(in: offset..<offset + typeFilterLength), encoding: .utf8) {
                typeFilter = parsedTypeFilter
            }
        }

        let actualTopPercentage = Double(bitPattern: UInt64(topPercentage))

        return await withCheckedContinuation { continuation in
            service.getUsageActivity(topPercentage: actualTopPercentage, dateString: dateString, typeFilter: typeFilter) { result, error in
                let response: IPCMessage
                if let error = error {
                    response = IPCMessage(type: .error, body: error.localizedDescription.data(using: .utf8) ?? Data())
                } else {
                    let responseString = result ?? "No usage data found"
                    response = IPCMessage(type: .response, body: responseString.data(using: .utf8) ?? Data())
                }
                continuation.resume(returning: response)
            }
        }
    }

    private func handleGetVersion() async -> IPCMessage {
        return await withCheckedContinuation { continuation in
            service.getVersion { version in
                let response = IPCMessage(type: .response, body: version.data(using: .utf8) ?? Data())
                continuation.resume(returning: response)
            }
        }
    }
}

// MARK: - IPC Protocol Codec

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
