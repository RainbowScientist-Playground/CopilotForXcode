import AppKit
import Foundation
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import Preferences
import Status
import XPCShared
import HostAppActivator

public class XPCService: NSObject, XPCServiceProtocol {
    // MARK: - Service

    public func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void) {
        reply(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        )
    }

    public func getXPCServiceAccessibilityPermission(withReply reply: @escaping (ObservedAXStatus) -> Void) {
        Task {
            reply(await Status.shared.getAXStatus())
        }
    }
    
    public func getXPCServiceExtensionPermission(
        withReply reply: @escaping (ExtensionPermissionStatus) -> Void
    ) {
        Task {
            reply(await Status.shared.getExtensionStatus())
        }
    }

    // MARK: - Suggestion

    @discardableResult
    private func replyWithUpdatedContent(
        editorContent: Data,
        file: StaticString = #file,
        line: UInt = #line,
        isRealtimeSuggestionRelatedCommand: Bool = false,
        withReply reply: @escaping (Data?, Error?) -> Void,
        getUpdatedContent: @escaping @ServiceActor (
            SuggestionCommandHandler,
            EditorContent
        ) async throws -> UpdatedContent?
    ) -> Task<Void, Never> {
        let task = Task {
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let handler: SuggestionCommandHandler = WindowBaseCommandHandler()
                try Task.checkCancellation()
                guard let updatedContent = try await getUpdatedContent(handler, editor) else {
                    reply(nil, nil)
                    return
                }
                try Task.checkCancellation()
                try reply(JSONEncoder().encode(updatedContent), nil)
            } catch {
                Logger.service.error("\(file):\(line) \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }

        Task {
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks(excluding: task)
        }
        return task
    }

    public func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentSuggestions(editor: editor)
        }
    }

    public func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentNextSuggestion(editor: editor)
        }
    }

    public func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentPreviousSuggestion(editor: editor)
        }
    }

    public func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.rejectSuggestion(editor: editor)
        }
    }

    public func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptSuggestion(editor: editor)
        }
    }

    public func getPromptToCodeAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptPromptToCode(editor: editor)
        }
    }

    public func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: reply
        ) { handler, editor in
            try await handler.presentRealtimeSuggestions(editor: editor)
        }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        // We don't need to wait for this.
        reply()

        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: { _, _ in }
        ) { handler, editor in
            try await handler.generateRealtimeSuggestions(editor: editor)
        }
    }

    public func openChat(
        withReply reply: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                // Check if app is already running
                if let _ = getRunningHostApp() {
                    // App is already running, use the chat service
                    let handler = PseudoCommandHandler()
                    handler.openChat(forceDetach: true)
                } else {
                    try launchHostAppDefault()
                }
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }

    public func promptToCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.promptToCode(editor: editor)
        }
    }

    public func customCommand(
        id: String,
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.customCommand(id: id, editor: editor)
        }
    }

    // MARK: - Settings

    public func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(NoAccessToAccessibilityAPIError())
            return
        }
        Task { @ServiceActor in
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks()
            let on = !UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            UserDefaults.shared.set(on, for: \.realtimeSuggestionToggle)
            Task { @MainActor in
                Service.shared.guiController.store
                    .send(.suggestionWidget(.toastPanel(.toast(.toast(
                        "Real-time suggestion is turned \(on ? "on" : "off")",
                        .info,
                        nil
                    )))))
            }
            reply(nil)
        }
    }

    public func postNotification(name: String, withReply reply: @escaping () -> Void) {
        reply()
        NotificationCenter.default.post(name: .init(name), object: nil)
    }

    public func quit(reply: @escaping () -> Void) {
        Task {
            await Service.shared.prepareForExit()
            reply()
        }
    }

    // MARK: - Requests

    public func send(
        endpoint: String,
        requestBody: Data,
        reply: @escaping (Data?, Error?) -> Void
    ) {
        Service.shared.handleXPCServiceRequests(
            endpoint: endpoint,
            requestBody: requestBody,
            reply: reply
        )
    }
}

struct NoAccessToAccessibilityAPIError: Error, LocalizedError {
    var errorDescription: String? {
        "Accessibility API permission is not granted. Please enable in System Settings.app."
    }

    init() {}
}
