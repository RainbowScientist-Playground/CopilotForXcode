import JSONRPC
import GitHubCopilotService

public typealias JSONRPCResponseHandler = (AnyJSONRPCResponse) -> Void

public protocol ConversationSkill {
    var id: String { get }
    func applies(params: ConversationContextParams) -> Bool
    func resolveSkill(request: ConversationContextRequest, completion: @escaping JSONRPCResponseHandler)
}
