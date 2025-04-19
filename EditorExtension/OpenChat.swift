import Client
import SuggestionBasic
import Foundation
import XcodeKit

class OpenChatCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Open Chat" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                try await service.openChat()
                completionHandler(nil)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
