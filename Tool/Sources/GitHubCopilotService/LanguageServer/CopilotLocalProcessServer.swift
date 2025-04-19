import Combine
import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger
import ProcessEnv
import Status

/// A clone of the `LocalProcessServer`.
/// We need it because the original one does not allow us to handle custom notifications.
class CopilotLocalProcessServer {
    public var notificationPublisher: PassthroughSubject<AnyJSONRPCNotification, Never> = PassthroughSubject<AnyJSONRPCNotification, Never>()
    public var serverRequestPublisher: PassthroughSubject<(AnyJSONRPCRequest, (AnyJSONRPCResponse) -> Void), Never> = PassthroughSubject<(AnyJSONRPCRequest, (AnyJSONRPCResponse) -> Void), Never>()
    
    private let transport: StdioDataTransport
    private let customTransport: CustomDataTransport
    private let process: Process
    private var wrappedServer: CustomJSONRPCLanguageServer?
    private var cancellables = Set<AnyCancellable>()
    var terminationHandler: (() -> Void)?
    @MainActor var ongoingCompletionRequestIDs: [JSONId] = []
    @MainActor var ongoingConversationRequestIDs = [String: JSONId]()
    
    public convenience init(
        path: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) {
        let params = Process.ExecutionParameters(
            path: path,
            arguments: arguments,
            environment: environment
        )

        self.init(executionParameters: params)
    }

    init(executionParameters parameters: Process.ExecutionParameters) {
        transport = StdioDataTransport()
        let framing = SeperatedHTTPHeaderMessageFraming()
        let messageTransport = MessageTransport(
            dataTransport: transport,
            messageProtocol: framing
        )
        customTransport = CustomDataTransport(nextTransport: messageTransport)
        wrappedServer = CustomJSONRPCLanguageServer(dataTransport: customTransport)

        process = Process()

        // Because the implementation of LanguageClient is so closed,
        // we need to get the request IDs from a custom transport before the data
        // is written to the language server.
        customTransport.onWriteRequest = { [weak self] request in
            if request.method == "getCompletionsCycling" {
                Task { @MainActor [weak self] in
                    self?.ongoingCompletionRequestIDs.append(request.id)
                }
            } else if request.method == "conversation/create" {
                Task { @MainActor [weak self] in
                    if let paramsData = try? JSONEncoder().encode(request.params) {
                        do {
                            let params = try JSONDecoder().decode(ConversationCreateParams.self, from: paramsData)
                            self?.ongoingConversationRequestIDs[params.workDoneToken] = request.id
                        } catch {
                            // Handle decoding error
                            print("Error decoding ConversationCreateParams: \(error)")
                            Logger.gitHubCopilot.error("Error decoding ConversationCreateParams: \(error)")
                        }
                    }
                }
            } else if request.method == "conversation/turn" {
                Task { @MainActor [weak self] in
                    if let paramsData = try? JSONEncoder().encode(request.params) {
                        do {
                            let params = try JSONDecoder().decode(TurnCreateParams.self, from: paramsData)
                            self?.ongoingConversationRequestIDs[params.workDoneToken] = request.id
                        } catch {
                            // Handle decoding error
                            print("Error decoding TurnCreateParams: \(error)")
                            Logger.gitHubCopilot.error("Error decoding TurnCreateParams: \(error)")
                        }
                    }
                }
            }
        }
        
        wrappedServer?.notificationPublisher.sink(receiveValue: { [weak self] notification in
            self?.notificationPublisher.send(notification)
        }).store(in: &cancellables)
        
        wrappedServer?.serverRequestPublisher.sink(receiveValue: { [weak self] (request, callback) in
            self?.serverRequestPublisher.send((request, callback))
        }).store(in: &cancellables)

        process.standardInput = transport.stdinPipe
        process.standardOutput = transport.stdoutPipe
        process.standardError = transport.stderrPipe
        
        process.parameters = parameters
        
        process.terminationHandler = { [unowned self] task in
            self.processTerminated(task)
        }
        
        process.launch()
    }

    deinit {
        process.terminationHandler = nil
        process.terminate()
        transport.close()
    }

    private func processTerminated(_: Process) {
        transport.close()

        // releasing the server here will short-circuit any pending requests,
        // which might otherwise take a while to time out, if ever.
        wrappedServer = nil
        terminationHandler?()
    }

    var logMessages: Bool {
        get { return wrappedServer?.logMessages ?? false }
        set { wrappedServer?.logMessages = newValue }
    }
}

extension CopilotLocalProcessServer: LanguageServerProtocol.Server {
    public var requestHandler: RequestHandler? {
        get { return wrappedServer?.requestHandler }
        set { wrappedServer?.requestHandler = newValue }
    }

    public var notificationHandler: NotificationHandler? {
        get { wrappedServer?.notificationHandler }
        set { wrappedServer?.notificationHandler = newValue }
    }

    public func sendNotification(
        _ notif: ClientNotification,
        completionHandler: @escaping (ServerError?) -> Void
    ) {
        guard let server = wrappedServer, process.isRunning else {
            completionHandler(.serverUnavailable)
            return
        }

        server.sendNotification(notif, completionHandler: completionHandler)
    }
    
    /// send copilot specific notification
    public func sendCopilotNotification(
        _ notif: CopilotClientNotification,
        completionHandler: @escaping (ServerError?) -> Void
    ) {
        guard let server = wrappedServer, process.isRunning else {
            completionHandler(.serverUnavailable)
            return
        }

        server.sendCopilotNotification(notif, completionHandler: completionHandler)
    }

    /// Cancel ongoing completion requests.
    public func cancelOngoingTasks() async {
        let task = Task { @MainActor in
            for id in ongoingCompletionRequestIDs {
                await cancelTask(id)
            }
            self.ongoingCompletionRequestIDs = []
        }
        await task.value
    }
    
    public func cancelOngoingTask(_ workDoneToken: String) async {
        let task = Task { @MainActor in
            guard let id = ongoingConversationRequestIDs[workDoneToken] else { return }
            await cancelTask(id)
        }
        await task.value
    }
    
    public func cancelTask(_ id: JSONId) async {
        guard let server = wrappedServer, process.isRunning else {
            return
        }
        
        switch id {
        case let .numericId(id):
            try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
        case let .stringId(id):
            try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
        }
    }

    public func sendRequest<Response: Codable>(
        _ request: ClientRequest,
        completionHandler: @escaping (ServerResult<Response>) -> Void
    ) {
        guard let server = wrappedServer, process.isRunning else {
            completionHandler(.failure(.serverUnavailable))
            return
        }

        server.sendRequest(request, completionHandler: completionHandler)
    }
}

protocol CopilotNotificationJSONRPCLanguageServer {
    func sendCopilotNotification(_ notif: CopilotClientNotification, completionHandler: @escaping (ServerError?) -> Void)
}

final class CustomJSONRPCLanguageServer: Server {
    let internalServer: JSONRPCLanguageServer

    typealias ProtocolResponse<T: Codable> = ProtocolTransport.ResponseResult<T>

    private let protocolTransport: ProtocolTransport

    public var requestHandler: RequestHandler?
    public var notificationHandler: NotificationHandler?
    public var notificationPublisher: PassthroughSubject<AnyJSONRPCNotification, Never> = PassthroughSubject<AnyJSONRPCNotification, Never>()
    public var serverRequestPublisher: PassthroughSubject<(AnyJSONRPCRequest, (AnyJSONRPCResponse) -> Void), Never> = PassthroughSubject<(AnyJSONRPCRequest, (AnyJSONRPCResponse) -> Void), Never>()

    private var outOfBandError: Error?

    init(protocolTransport: ProtocolTransport) {
        self.protocolTransport = protocolTransport
        internalServer = JSONRPCLanguageServer(protocolTransport: protocolTransport)

        let previouseRequestHandler = protocolTransport.requestHandler
        let previouseNotificationHandler = protocolTransport.notificationHandler

        protocolTransport
            .requestHandler = { [weak self] in
                guard let self else { return }
                if !self.handleRequest($0, data: $1, callback: $2) {
                    previouseRequestHandler?($0, $1, $2)
                }
            }
        protocolTransport
            .notificationHandler = { [weak self] in
                guard let self else { return }
                if !self.handleNotification($0, data: $1, block: $2) {
                    previouseNotificationHandler?($0, $1, $2)
                }
            }
    }

    convenience init(dataTransport: DataTransport) {
        self.init(protocolTransport: ProtocolTransport(dataTransport: dataTransport))
    }

    deinit {
        protocolTransport.requestHandler = nil
        protocolTransport.notificationHandler = nil
    }

    var logMessages: Bool {
        get { return internalServer.logMessages }
        set { internalServer.logMessages = newValue }
    }
}

extension CustomJSONRPCLanguageServer {
    private func handleNotification(
        _ anyNotification: AnyJSONRPCNotification,
        data: Data,
        block: @escaping (Error?) -> Void
    ) -> Bool {
        let methodName = anyNotification.method
        let debugDescription = {
            if let params = anyNotification.params {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let jsonData = try? encoder.encode(params),
                   let text = String(data: jsonData, encoding: .utf8)
                {
                    return text
                }
            }
            return "N/A"
        }()
        
        if let method = ServerNotification.Method(rawValue: methodName) {
            switch method {
            case .windowLogMessage:
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                block(nil)
                return true
            case .protocolProgress:
                notificationPublisher.send(anyNotification)
                block(nil)
                return true
            default:
                return false
            }
        } else {
            switch methodName {
            case "LogMessage":
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                block(nil)
                return true
            case "didChangeStatus":
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                if let payload = GitHubCopilotNotification.StatusNotification.decode(fromParams: anyNotification.params) {
                    Task {
                        await Status.shared
                            .updateCLSStatus(
                                payload.kind.clsStatus,
                                busy: payload.busy,
                                message: payload.message ?? ""
                            )
                    }
                }
                block(nil)
                return true
            case "featureFlagsNotification":
                notificationPublisher.send(anyNotification)
                block(nil)
                return true
            case "conversation/preconditionsNotification", "statusNotification":
                // Ignore
                block(nil)
                return true
            default:
                return false
            }
        }
    }

    public func sendNotification(
        _ notif: ClientNotification,
        completionHandler: @escaping (ServerError?) -> Void
    ) {
        internalServer.sendNotification(notif, completionHandler: completionHandler)
    }
}

extension CustomJSONRPCLanguageServer {
    private func handleRequest(
        _ request: AnyJSONRPCRequest,
        data: Data,
        callback: @escaping (AnyJSONRPCResponse) -> Void
    ) -> Bool {
        serverRequestPublisher.send((request: request, callback: callback))
        switch request.method {
        case "copilot/watchedFiles":
            return true
        default:
            return false
        }
    }
}

extension CustomJSONRPCLanguageServer {
    public func sendRequest<Response: Codable>(
        _ request: ClientRequest,
        completionHandler: @escaping (ServerResult<Response>) -> Void
    ) {
        internalServer.sendRequest(request, completionHandler: completionHandler)
    }
}

// MARK: - Copilot custom notification

public struct CopilotDidChangeWatchedFilesParams: Codable, Hashable {
    /// The CLS need an additional paramter `workspaceUri` for "workspace/didChangeWatchedFiles" event
    public var workspaceUri: String
    public var changes: [FileEvent]

    public init(workspaceUri: String, changes: [FileEvent]) {
        self.workspaceUri = workspaceUri
        self.changes = changes
    }
}

public enum CopilotClientNotification {
    public enum Method: String {
        case workspaceDidChangeWatchedFiles = "workspace/didChangeWatchedFiles"
    }
    
    case copilotDidChangeWatchedFiles(CopilotDidChangeWatchedFilesParams)
    
    public var method: Method {
        switch self {
        case .copilotDidChangeWatchedFiles:
            return .workspaceDidChangeWatchedFiles
        }
    }
}

extension CustomJSONRPCLanguageServer: CopilotNotificationJSONRPCLanguageServer {
    public func sendCopilotNotification(_ notif: CopilotClientNotification, completionHandler: @escaping (ServerError?) -> Void) {
        let method = notif.method.rawValue
        
        switch notif {
        case .copilotDidChangeWatchedFiles(let params):
            // the protocolTransport is not exposed by LSP Server, need to use it directly
            protocolTransport.sendNotification(params, method: method) { error in
                completionHandler(error.map({ .unableToSendNotification($0) }))
            }
        }
    }
}
