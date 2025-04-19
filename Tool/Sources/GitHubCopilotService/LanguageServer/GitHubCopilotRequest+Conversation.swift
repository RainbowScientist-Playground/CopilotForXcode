import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol
import SuggestionBasic
import ConversationServiceProvider
import JSONRPC
import Logger

enum ConversationSource: String, Codable {
    case panel, inline
}

public struct Doc: Codable {
    var position: Position?
    var uri: String
}

public struct Reference: Codable, Equatable, Hashable {
    public var type: String = "file"
    public let uri: String
    public let position: Position?
    public let visibleRange: SuggestionBasic.CursorRange?
    public let selection: SuggestionBasic.CursorRange?
    public let openedAt: String?
    public let activeAt: String?
}

struct ConversationCreateParams: Codable {
    var workDoneToken: String
    var turns: [ConversationTurn]
    var capabilities: Capabilities
    var doc: Doc?
    var references: [Reference]?
    var computeSuggestions: Bool?
    var source: ConversationSource?
    var workspaceFolder: String?
    var ignoredSkills: [String]?
    var model: String?

    struct Capabilities: Codable {
        var skills: [String]
        var allSkills: Bool?
    }
}

// MARK: Conversation Progress

public enum ConversationProgressKind: String, Codable {
    case begin, report, end
}

protocol BaseConversationProgress: Codable {
    var kind: ConversationProgressKind { get }
    var conversationId: String { get }
    var turnId: String { get }
}

public struct ConversationProgressBegin: BaseConversationProgress {
    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
}

public struct ConversationProgressReport: BaseConversationProgress {

    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
    public let reply: String?
    public let references: [Reference]?
    public let steps: [ConversationProgressStep]?
}

public struct ConversationProgressEnd: BaseConversationProgress {
    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
    public let error: CopilotLanguageServerError?
    public let followUp: ConversationFollowUp?
    public let suggestedTitle: String?
}

enum ConversationProgressContainer: Decodable {
    case begin(ConversationProgressBegin)
    case report(ConversationProgressReport)
    case end(end: ConversationProgressEnd)

    enum CodingKeys: String, CodingKey {
        case kind
    }

    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(ConversationProgressKind.self, forKey: .kind)

            switch kind {
            case .begin:
                let begin = try ConversationProgressBegin(from: decoder)
                self = .begin(begin)
            case .report:
                let report = try ConversationProgressReport(from: decoder)
                self = .report(report)
            case .end:
                let end = try ConversationProgressEnd(from: decoder)
                self = .end(end: end)
            }
        } catch {
            Logger.gitHubCopilot.error("Error decoding ConversationProgressContainer: \(error)")
            throw error
        }
     }
 }

// MARK: Conversation rating

struct ConversationRatingParams: Codable {
    var turnId: String
    var rating: ConversationRating
    var doc: Doc?
    var source: ConversationSource?
}

// MARK: Conversation turn

struct ConversationTurn: Codable {
    var request: String
    var response: String?
    var turnId: String?
}

struct TurnCreateParams: Codable {
    var workDoneToken: String
    var conversationId: String
    var message: String
    var doc: Doc?
    var ignoredSkills: [String]?
    var references: [Reference]?
    var model: String?
    var workspaceFolder: String?
}

// MARK: Copy

struct CopyCodeParams: Codable {
    var turnId: String
    var codeBlockIndex: Int
    var copyType: CopyKind
    var copiedCharacters: Int
    var totalCharacters: Int
    var copiedText: String
    var doc: Doc?
    var source: ConversationSource?
}

// MARK: Conversation context

public struct ConversationContextParams: Codable {
    public var conversationId: String
    public var turnId: String
    public var skillId: String
}

public typealias ConversationContextRequest = JSONRPCRequest<ConversationContextParams>


// MARK: Watched Files

public struct WatchedFilesParams: Codable {
    public var workspaceUri: String
    public var excludeGitignoredFiles: Bool
    public var excludeIDEIgnoredFiles: Bool
}

public typealias WatchedFilesRequest = JSONRPCRequest<WatchedFilesParams>
