import Foundation
import Combine
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger

protocol ServerRequestHandler {
    func handleRequest(_ request: AnyJSONRPCRequest, callback: @escaping (AnyJSONRPCResponse) -> Void)
}

class ServerRequestHandlerImpl : ServerRequestHandler {
    public static let shared = ServerRequestHandlerImpl()
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    
    func handleRequest(_ request: AnyJSONRPCRequest, callback: @escaping (AnyJSONRPCResponse) -> Void) {
        let methodName = request.method
        switch methodName {
        case "conversation/context":
            do {
                let params = try JSONEncoder().encode(request.params)
                let contextParams = try JSONDecoder().decode(ConversationContextParams.self, from: params)
                conversationContextHandler.handleConversationContext(
                    ConversationContextRequest(id: request.id, method: request.method, params: contextParams),
                    completion: callback)

            } catch {
                callback(
                    AnyJSONRPCResponse(
                        id: request.id,
                        result: JSONValue.array([
                            JSONValue.null,
                            JSONValue.hash([
                                "code": .number(-32602/* Invalid params */),
                                "message": .string("Error: \(error.localizedDescription)")])
                        ])
                    )
                )
                Logger.gitHubCopilot.error(error)
            }
            break
        default:
            break
        }
    }
}
