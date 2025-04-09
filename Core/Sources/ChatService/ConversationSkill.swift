import JSONRPC
import GitHubCopilotService

public protocol ConversationSkill {
    var id: String { get }
    func applies(params: ConversationContextParams) -> Bool
    func resolveSkill(request: ConversationContextRequest, completion: @escaping (AnyJSONRPCResponse) -> Void)
}
