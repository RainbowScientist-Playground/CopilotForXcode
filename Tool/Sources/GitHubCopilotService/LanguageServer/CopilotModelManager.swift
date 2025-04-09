import ConversationServiceProvider

public class CopilotModelManager {
    private static var availableLLMs: [CopilotModel] = []
    
    public static func updateLLMs(_ models: [CopilotModel]) {
        availableLLMs = models
    }

    public static func getAvailableLLMs() -> [CopilotModel] {
        return availableLLMs
    }
    
    public static func hasLLMs() -> Bool {
        return !availableLLMs.isEmpty
    }

    public static func clearLLMs() {
        availableLLMs = []
    }
}
