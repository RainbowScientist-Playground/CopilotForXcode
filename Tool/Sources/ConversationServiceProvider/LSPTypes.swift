
// MARK: Conversation template
public struct ChatTemplate: Codable, Equatable {
    public var id: String
    public var description: String
    public var shortDescription: String
    public var scopes: [PromptTemplateScope]
    
    public init(id: String, description: String, shortDescription: String, scopes: [PromptTemplateScope]=[]) {
        self.id = id
        self.description = description
        self.shortDescription = shortDescription
        self.scopes = scopes
    }
}

public enum PromptTemplateScope: String, Codable, Equatable {
    case chatPanel = "chat-panel"
    case editPanel = "edit-panel"
    case editor = "editor"
    case inline = "inline"
    case completion = "completion"
}

public struct CopilotLanguageServerError: Codable {
    public var code: Int?
    public var message: String
    public var responseIsIncomplete: Bool?
    public var responseIsFiltered: Bool?
}

// MARK: Copilot Model
public struct CopilotModel: Codable, Equatable {
    public let modelFamily: String
    public let modelName: String
    public let id: String
    public let modelPolicy: CopilotModelPolicy?
    public let scopes: [PromptTemplateScope]
    public let preview: Bool
}

public struct CopilotModelPolicy: Codable, Equatable {
    public let state: String
    public let terms: String
}

// MARK: Conversation Agents
public struct ChatAgent: Codable, Equatable {
    public let slug: String
    public let name: String
    public let description: String
    public let avatarUrl: String?
    
    public init(slug: String, name: String, description: String, avatarUrl: String?) {
        self.slug = slug
        self.name = name
        self.description = description
        self.avatarUrl = avatarUrl
    }
}
