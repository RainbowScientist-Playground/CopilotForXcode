import Foundation

public enum DatabaseError: Error {
    case connectionFailed(String)
    case invalidPath(String)
    case connectionLost
}
