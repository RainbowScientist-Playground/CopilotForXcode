import TelemetryServiceProvider
import CopilotForXcodeKit
import Foundation
import Logger
import XcodeInspector

public final class BuiltinExtensionTelemetryServiceProvider<
    T: BuiltinExtension
>: TelemetryServiceProvider {
    
    private let extensionManager: BuiltinExtensionManager

    public init(
        extension: T.Type,
        extensionManager: BuiltinExtensionManager = .shared
    ) {
        self.extensionManager = extensionManager
    }

    var telemetryService: TelemetryServiceType? {
        extensionManager.extensions.first { $0 is T }?.telemetryService
    }
    
    private func activeWorkspace() async -> WorkspaceInfo? {
        guard let workspaceURL = await XcodeInspector.shared.safe.realtimeActiveWorkspaceURL,
              let projectURL = await XcodeInspector.shared.safe.realtimeActiveProjectURL
        else { return nil }
        
        return WorkspaceInfo(workspaceURL: workspaceURL, projectURL: projectURL)
    }
    
    struct BuiltinExtensionTelemetryServiceNotFoundError: Error, LocalizedError {
        var errorDescription: String? {
            "Builtin telemetry service not found."
        }
    }
    
    struct BuiltinExtensionActiveWorkspaceInfoNotFoundError: Error, LocalizedError {
        var errorDescription: String? {
            "Builtin active workspace info not found."
        }
    }

    public func sendError(_ request: TelemetryExceptionRequest) async throws {
        guard let telemetryService else {
            print("Builtin telemetry service not found.")
            throw BuiltinExtensionTelemetryServiceNotFoundError()
        }
        guard let workspaceInfo = await activeWorkspace() else {
            print("Builtin active workspace info not found.")
            throw BuiltinExtensionActiveWorkspaceInfoNotFoundError()
        }
        
        try await telemetryService.sendError(
            request,
            workspace: workspaceInfo
        )
    }
}
