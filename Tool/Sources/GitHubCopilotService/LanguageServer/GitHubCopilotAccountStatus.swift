import Foundation

public enum GitHubCopilotAccountStatus: String, Codable, CustomStringConvertible {
    case alreadySignedIn = "AlreadySignedIn"
    case maybeOk = "MaybeOk"
    case notAuthorized = "NotAuthorized"
    case notSignedIn = "NotSignedIn"
    case ok = "OK"
    case failedToGetToken = "FailedToGetToken"

    public var description: String {
        switch self {
        case .alreadySignedIn:
            return "Already Signed In"
        case .maybeOk:
            return "Unknown"
        case .notAuthorized:
            return "No Subscription"
        case .notSignedIn:
            return "Not Signed In"
        case .ok:
            return "Active"
        case .failedToGetToken:
            return "Failed to Get Token"
        }
    }
}
