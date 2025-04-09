import JSONRPC
import Combine

public protocol ConversationContextHandler {
    var onConversationContext: PassthroughSubject<(ConversationContextRequest, (AnyJSONRPCResponse) -> Void), Never> { get }
    func handleConversationContext(_ request: ConversationContextRequest, completion: @escaping (AnyJSONRPCResponse) -> Void)
}

public final class ConversationContextHandlerImpl: ConversationContextHandler {
    public static let shared = ConversationContextHandlerImpl()

    public var onConversationContext = PassthroughSubject<(ConversationContextRequest, (AnyJSONRPCResponse) -> Void), Never>()
    
    public func handleConversationContext(_ request: ConversationContextRequest, completion: @escaping (AnyJSONRPCResponse) -> Void) {
        onConversationContext.send((request, completion))
    }
}
