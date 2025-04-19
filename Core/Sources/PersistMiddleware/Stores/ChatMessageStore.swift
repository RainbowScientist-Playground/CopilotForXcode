import Persist
import ChatAPIService

public struct ChatMessageStore {
    public static func save(_ chatMessage: ChatMessage, with metadata: StorageMetadata) {
        let turnItem = chatMessage.toTurnItem()
        ConversationStorageService.shared.operate(
            OperationRequest([.upsertTurn([turnItem])]),
            metadata: metadata)
    }
    
    public static func delete(by id: String, with metadata: StorageMetadata) {
        ConversationStorageService.shared.operate(
            OperationRequest([.delete([.turn(id: id)])]), metadata: metadata)
    }
    
    public static func deleteAll(by ids: [String], with metadata: StorageMetadata) {
        ConversationStorageService.shared.operate(
            OperationRequest([.delete(ids.map { .turn(id: $0)})]), metadata: metadata)
    }
    
    public static func getAll(by conversationID: String, metadata: StorageMetadata) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []
        
        let turnItems = ConversationStorageService.shared.fetchTurnItems(for: conversationID, metadata: metadata)
        if turnItems.count > 0 {
            chatMessages = turnItems.compactMap { ChatMessage.from($0) }
        }
        
        return chatMessages
    }
}
