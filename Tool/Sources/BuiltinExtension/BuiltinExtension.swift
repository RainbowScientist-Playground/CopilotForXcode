import CopilotForXcodeKit
import Foundation
import Preferences
import ConversationServiceProvider
import TelemetryServiceProvider

public typealias CopilotForXcodeCapability = CopilotForXcodeExtensionCapability & CopilotForXcodeChatCapability & CopilotForXcodeTelemetryCapability

public protocol CopilotForXcodeChatCapability {
    var conversationService: ConversationServiceType? { get }
}

public protocol CopilotForXcodeTelemetryCapability {
    var telemetryService: TelemetryServiceType? { get }
}

public protocol BuiltinExtension: CopilotForXcodeCapability {
    /// An id that let the extension manager determine whether the extension is in use.
    var suggestionServiceId: BuiltInSuggestionFeatureProvider { get }

    /// It's usually called when the app is about to quit,
    /// you should clean up all the resources here.
    func terminate()
}

