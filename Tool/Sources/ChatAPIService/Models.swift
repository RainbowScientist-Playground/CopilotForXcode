import CodableWrappers
import Foundation
import ConversationServiceProvider
import GitHubCopilotService

// move here avoid circular reference
public struct ConversationReference: Codable, Equatable, Hashable {
    public enum Kind: Codable, Equatable, Hashable {
        case `class`
        case `struct`
        case `enum`
        case `actor`
        case `protocol`
        case `extension`
        case `case`
        case property
        case `typealias`
        case function
        case method
        case text
        case webpage
        case other
        // reference for turn - request
        case fileReference(FileReference)
        // reference from turn - response
        case reference(Reference)
    }
    
    public enum Status: String, Codable {
        case included, blocked, notfound, empty
    }

    public var uri: String
    public var status: Status?
    public var kind: Kind
    
    public var ext: String {
        return url?.pathExtension ?? ""
    }
    
    public var fileName: String {
        return url?.lastPathComponent ?? ""
    }
    
    public var filePath: String {
        return url?.path ?? ""
    }
    
    public var url: URL? {
        return URL(string: uri)
    }

    public init(
        uri: String,
        status: Status?,
        kind: Kind
    ) {
        self.uri = uri
        self.status = status
        self.kind = kind
        
    }
}


public struct ChatMessage: Equatable, Codable {
    public typealias ID = String

    public enum Role: String, Codable, Equatable {
        case system
        case user
        case assistant
    }
    
    /// The role of a message.
    public var role: Role

    /// The content of the message, either the chat message, or a result of a function call.
    public var content: String

    /// The id of the message.
    public var id: ID
    
    /// The conversation id (not the CLS conversation id)
    public var chatTabID: String
    
    /// The CLS turn id of the message which is from CLS.
    public var clsTurnID: ID?
    
    /// Rate assistant message
    public var rating: ConversationRating

    /// The references of this message.
    public var references: [ConversationReference]
    
    /// The followUp question of this message
    public var followUp: ConversationFollowUp?
    
    public var suggestedTitle: String?

    /// The error occurred during responding chat in server
    public var errorMessage: String?
    
    /// The steps of conversation progress
    public var steps: [ConversationProgressStep]
    
    /// The timestamp of the message.
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        chatTabID: String,
        clsTurnID: String? = nil,
        role: Role,
        content: String,
        references: [ConversationReference] = [],
        followUp: ConversationFollowUp? = nil,
        suggestedTitle: String? = nil,
        errorMessage: String? = nil,
        rating: ConversationRating = .unrated,
        steps: [ConversationProgressStep] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.role = role
        self.content = content
        self.id = id
        self.chatTabID = chatTabID
        self.clsTurnID = clsTurnID
        self.references = references
        self.followUp = followUp
        self.suggestedTitle = suggestedTitle
        self.errorMessage = errorMessage
        self.rating = rating
        self.steps = steps

        let now = Date.now
        self.createdAt = createdAt ?? now
        self.updatedAt = updatedAt ?? now
    }
}

extension ConversationReference {
  public func getPathRelativeToHome() -> String {
        guard !filePath.isEmpty else { return filePath}
        
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if !homeDirectory.isEmpty{
            return filePath.replacingOccurrences(of: homeDirectory, with: "~")
        }
        
        return filePath
    }
}
