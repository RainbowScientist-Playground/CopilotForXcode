import Persist
import ChatTab

public struct ChatTabInfoStore {
    public static func saveAll(_ chatTabInfos: [ChatTabInfo], with metadata: StorageMetadata) {
        let conversationItems = chatTabInfos.toConversationItems()
        ConversationStorageService.shared.operate(
            OperationRequest([.upsertConversation(conversationItems)]), metadata: metadata)
    }
    
    public static func delete(by id: String, with metadata: StorageMetadata) {
        ConversationStorageService.shared.operate(
            OperationRequest(
                [.delete([.conversation(id: id), .turnByConversationID(conversationID: id)])]),
            metadata: metadata)
    }
    
    public static func getAll(with metadata: StorageMetadata) -> [ChatTabInfo] {
        var chatTabInfos: [ChatTabInfo] = []
        
        let conversationItems = ConversationStorageService.shared.fetchConversationItems(.all, metadata: metadata)
        if conversationItems.count > 0 {
            chatTabInfos = conversationItems.compactMap { ChatTabInfo.from($0, with: metadata) }
        }
        
        return chatTabInfos
    }
}
