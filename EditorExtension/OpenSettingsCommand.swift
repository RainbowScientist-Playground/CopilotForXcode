//
//  OpenSettingsCommand.swift
//  EditorExtension
//
//  Opens the settings app
//

import Foundation
import XcodeKit
import HostAppActivator



class OpenSettingsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Open \(hostAppName()) Settings" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try launchHostAppSettings()
                completionHandler(nil)
            } catch {
                completionHandler(
                    GitHubCopilotForXcodeSettingsLaunchError
                        .openFailed(
                            errorDescription: error.localizedDescription
                        )
                )
            }
        }
    }
}

func hostAppName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
        ?? "GitHub Copilot for Xcode"
}
