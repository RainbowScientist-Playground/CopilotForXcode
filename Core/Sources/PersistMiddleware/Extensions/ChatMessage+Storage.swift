import Foundation
import ChatAPIService
import Persist
import Logger
import ConversationServiceProvider

extension ChatMessage {
    
    struct TurnItemData: Codable {
        var content: String
        var rating: ConversationRating
        var references: [ConversationReference]
        var followUp: ConversationFollowUp?
        var suggestedTitle: String?
        var errorMessage: String?
        var steps: [ConversationProgressStep]

        // Custom decoder to provide default value for steps
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decode(String.self, forKey: .content)
            rating = try container.decode(ConversationRating.self, forKey: .rating)
            references = try container.decode([ConversationReference].self, forKey: .references)
            followUp = try container.decodeIfPresent(ConversationFollowUp.self, forKey: .followUp)
            suggestedTitle = try container.decodeIfPresent(String.self, forKey: .suggestedTitle)
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            steps = try container.decodeIfPresent([ConversationProgressStep].self, forKey: .steps) ?? []
        }

        // Default memberwise init for encoding
        init(content: String, rating: ConversationRating, references: [ConversationReference], followUp: ConversationFollowUp?, suggestedTitle: String?, errorMessage: String?, steps: [ConversationProgressStep]?) {
            self.content = content
            self.rating = rating
            self.references = references
            self.followUp = followUp
            self.suggestedTitle = suggestedTitle
            self.errorMessage = errorMessage
            self.steps = steps ?? []
        }
    }
    
    func toTurnItem() -> TurnItem {
        let turnItemData = TurnItemData(
            content: self.content,
            rating: self.rating,
            references: self.references,
            followUp: self.followUp,
            suggestedTitle: self.suggestedTitle,
            errorMessage: self.errorMessage,
            steps: self.steps
        )
        
        // TODO: handle exception
        let encoder = JSONEncoder()
        let encodeData = (try? encoder.encode(turnItemData)) ?? Data()
        let data = String(data: encodeData, encoding: .utf8) ?? "{}"
        
        return TurnItem(id: self.id, conversationID: self.chatTabID, CLSTurnID: self.clsTurnID, role: role.rawValue, data: data, createdAt: self.createdAt, updatedAt: self.updatedAt)
    }
    
    static func from(_ turnItem: TurnItem) -> ChatMessage? {
        var chatMessage: ChatMessage? = nil
                
        do {
            if let jsonData = turnItem.data.data(using: .utf8) {
                let decoder = JSONDecoder()
                let turnItemData = try decoder.decode(TurnItemData.self, from: jsonData)
                
                chatMessage = .init(
                    id: turnItem.id,
                    chatTabID: turnItem.conversationID,
                    clsTurnID: turnItem.CLSTurnID,
                    role: ChatMessage.Role(rawValue: turnItem.role)!,
                    content: turnItemData.content,
                    references: turnItemData.references,
                    followUp: turnItemData.followUp,
                    suggestedTitle: turnItemData.suggestedTitle,
                    errorMessage: turnItemData.errorMessage,
                    rating: turnItemData.rating,
                    steps: turnItemData.steps,
                    createdAt: turnItem.createdAt,
                    updatedAt: turnItem.updatedAt
                )
            }
        } catch {
            Logger.client.error("Failed to restore chat message: \(error)")
        }
        
        return chatMessage
    }
}

extension Array where Element == ChatMessage {
    func toTurnItems() -> [TurnItem] {
        return self.map { $0.toTurnItem() }
    }
}
