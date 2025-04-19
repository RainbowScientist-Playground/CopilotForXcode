import Foundation
import JSONRPC
import LanguageServerProtocol
import Status
import SuggestionBasic
import ConversationServiceProvider

struct GitHubCopilotDoc: Codable {
    var source: String
    var tabSize: Int
    var indentSize: Int
    var insertSpaces: Bool
    var path: String
    var uri: String
    var relativePath: String
    var languageId: CodeLanguage
    var position: Position
    /// Buffer version. Not sure what this is for, not sure how to get it
    var version: Int = 0
}

protocol GitHubCopilotRequestType {
    associatedtype Response: Codable
    var request: ClientRequest { get }
}

public struct GitHubCopilotCodeSuggestion: Codable, Equatable {
    public init(
        text: String,
        position: CursorPosition,
        uuid: String,
        range: CursorRange,
        displayText: String
    ) {
        self.text = text
        self.position = position
        self.uuid = uuid
        self.range = range
        self.displayText = displayText
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var uuid: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// The new code to be inserted.
    public var displayText: String
}

public func editorConfiguration() -> JSONValue {
    var proxyAuthorization: String? {
        let username = UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername)
        if username.isEmpty { return nil }
        let password = UserDefaults.shared.value(for: \.gitHubCopilotProxyPassword)
        return "\(username):\(password)"
    }

    var http: JSONValue? {
        var d: [String: JSONValue] = [:]
        let proxy = UserDefaults.shared.value(for: \.gitHubCopilotProxyUrl)
        if !proxy.isEmpty {
            d["proxy"] = .string(proxy)
        }
        if let proxyAuthorization = proxyAuthorization {
            d["proxyAuthorization"] = .string(proxyAuthorization)
        }
        let proxyStrictSSL = UserDefaults.shared.value(for: \.gitHubCopilotUseStrictSSL)
        d["proxyStrictSSL"] = .bool(proxyStrictSSL)
        if proxy.isEmpty && proxyStrictSSL == false {
            // Setting the proxy to an empty string avoids the lanaguage server
            // ignoring the proxyStrictSSL setting.
            d["proxy"] = .string("")
        }
        return .hash(d)
    }

    var authProvider: JSONValue? {
        let enterpriseURI = UserDefaults.shared.value(for: \.gitHubCopilotEnterpriseURI)
        return .hash([ "uri": .string(enterpriseURI) ])
    }

    var d: [String: JSONValue] = [:]
    if let http { d["http"] = http }
    if let authProvider { d["github-enterprise"] = authProvider }
    return .hash(d)
}

public enum SignInInitiateStatus: String, Codable {
    case promptUserDeviceFlow = "PromptUserDeviceFlow"
    case alreadySignedIn = "AlreadySignedIn"
}

enum GitHubCopilotRequest {
    struct GetVersion: GitHubCopilotRequestType {
        struct Response: Codable {
            var version: String
        }

        var request: ClientRequest {
            .custom("getVersion", .hash([:]))
        }
    }

    struct CheckStatus: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String?
        }

        var request: ClientRequest {
            .custom("checkStatus", .hash([:]))
        }
    }

    struct SignInInitiate: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: SignInInitiateStatus
            var userCode: String?
            var verificationUri: String?
            var expiresIn: Int?
            var interval: Int?
            var user: String?
        }

        var request: ClientRequest {
            .custom("signInInitiate", .hash([:]))
        }
    }

    struct SignInConfirm: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String
        }

        var userCode: String

        var request: ClientRequest {
            .custom("signInConfirm", .hash([
                "userCode": .string(userCode),
            ]))
        }
    }

    struct SignOut: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("signOut", .hash([:]))
        }
    }

    struct GetCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetCompletionsCycling: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletionsCycling", .hash([
                "doc": dict,
            ]))
        }
    }

    struct InlineCompletion: GitHubCopilotRequestType {
        struct Response: Codable {
            var items: [InlineCompletionItem]
        }

        struct InlineCompletionItem: Codable {
            var insertText: String
            var filterText: String?
            var range: Range?
            var command: Command?

            struct Range: Codable {
                var start: Position
                var end: Position
            }

            struct Command: Codable {
                var title: String
                var command: String
                var arguments: [String]?
            }
        }

        var doc: Input

        struct Input: Codable {
            var textDocument: _TextDocument; struct _TextDocument: Codable {
                var uri: String
                var version: Int
            }

            var position: Position
            var formattingOptions: FormattingOptions
            var context: _Context; struct _Context: Codable {
                enum TriggerKind: Int, Codable {
                    case invoked = 1
                    case automatic = 2
                }

                var triggerKind: TriggerKind
            }
        }

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("textDocument/inlineCompletion", dict)
        }
    }

    struct GetPanelCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getPanelCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct NotifyShown: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var request: ClientRequest {
            .custom("notifyShown", .hash([
                "uuid": .string(completionUUID),
            ]))
        }
    }

    struct NotifyAccepted: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var acceptedLength: Int?

        var request: ClientRequest {
            var dict: [String: JSONValue] = [
                "uuid": .string(completionUUID),
            ]
            if let acceptedLength {
                dict["acceptedLength"] = .number(Double(acceptedLength))
            }

            return .custom("notifyAccepted", .hash(dict))
        }
    }

    struct NotifyRejected: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUIDs: [String]

        var request: ClientRequest {
            .custom("notifyRejected", .hash([
                "uuids": .array(completionUUIDs.map(JSONValue.string)),
            ]))
        }
    }

    // MARK: Conversation

    struct CreateConversation: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: ConversationCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/create", dict)
        }
    }

    // MARK: Conversation turn

    struct CreateTurn: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: TurnCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/turn", dict)
        }
    }

    // MARK: Conversation rating

    struct ConversationRating: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: ConversationRatingParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/rating", dict)
        }
    }
    
    // MARK: Conversation templates

    struct GetTemplates: GitHubCopilotRequestType {
        typealias Response = Array<ChatTemplate>

        var request: ClientRequest {
            .custom("conversation/templates", .hash([:]))
        }
    }

    struct CopilotModels: GitHubCopilotRequestType {
        typealias Response = Array<CopilotModel>

        var request: ClientRequest {
            .custom("copilot/models", .hash([:]))
        }
    }
    
    // MARK: - Conversation Agents
    
    struct GetAgents: GitHubCopilotRequestType {
        typealias Response = Array<ChatAgent>

        var request: ClientRequest {
            .custom("conversation/agents", .hash([:]))
        }
    }

    // MARK: Copy code

    struct CopyCode: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: CopyCodeParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/copyCode", dict)
        }
    }
    
    // MARK: Telemetry

    struct TelemetryException: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: TelemetryExceptionParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("telemetry/exception", dict)
        }
    }
}

// MARK: Notifications

public enum GitHubCopilotNotification {

    public struct StatusNotification: Codable {
        public enum StatusKind : String, Codable {
            case normal = "Normal"
            case error = "Error"
            case warning = "Warning"
            case inactive = "Inactive"

            public var clsStatus: CLSStatus.Status {
                switch self {
                case .normal:
                        .normal
                case .error:
                        .error
                case .warning:
                        .warning
                case .inactive:
                        .inactive
                }
            }
        }

        public var kind: StatusKind
        public var busy: Bool
        public var message: String?

        public static func decode(fromParams params: JSONValue?) -> StatusNotification? {
            try? JSONDecoder().decode(Self.self, from: (try? JSONEncoder().encode(params)) ?? Data())
        }
    }

}
