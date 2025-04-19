import CopilotForXcodeKit
import Foundation
import TelemetryServiceProvider
import BuiltinExtension

public final class GitHubCopilotTelemetryService: TelemetryServiceType {
    
    private let serviceLocator: ServiceLocator

    init(serviceLocator: ServiceLocator) {
        self.serviceLocator = serviceLocator
    }
    
    public func sendError(_ request: TelemetryExceptionRequest,
                                       workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        let sessionId = service.getSessionId()
        var properties = request.properties ?? [:]
        properties.updateValue(sessionId, forKey: "common_vscodesessionid")
        properties.updateValue(sessionId, forKey: "client_sessionid")
        
        try await service.sendError(
            transaction: request.transaction,
            stacktrace: request.stacktrace,
            properties: properties,
            platform: request.platform,
            exceptionDetail: request.exceptionDetail
        )
    }
}
