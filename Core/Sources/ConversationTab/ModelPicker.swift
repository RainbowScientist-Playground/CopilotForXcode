import SwiftUI
import ChatService
import Persist
import ComposableArchitecture
import GitHubCopilotService

public let SELECTED_LLM_KEY = "selectedLLM"

extension AppState {
    func getSelectedModelFamily() -> String? {
        if let savedModel = get(key: SELECTED_LLM_KEY),
           let modelFamily = savedModel["modelFamily"]?.stringValue {
            return modelFamily
        }
        return nil
    }

    func getSelectedModelName() -> String? {
        if let savedModel = get(key: SELECTED_LLM_KEY),
           let modelName = savedModel["modelName"]?.stringValue {
            return modelName
        }
        return nil
    }

    func setSelectedModel(_ model: LLMModel) {
        update(key: SELECTED_LLM_KEY, value: model)
    }
}

extension CopilotModelManager {
    static func getAvailableChatLLMs() -> [LLMModel] {
        let LLMs = CopilotModelManager.getAvailableLLMs()
        return LLMs.filter(
            { $0.scopes.contains(.chatPanel) }
        ).map {
            LLMModel(modelName: $0.modelName, modelFamily: $0.modelFamily)
        }
    }
}

struct LLMModel: Codable, Hashable {
    let modelName: String
    let modelFamily: String
}

let defaultModel = LLMModel(modelName: "GPT-4o", modelFamily: "gpt-4o")
struct ModelPicker: View {
    @State private var selectedModel = defaultModel.modelName
    @State private var isHovered = false
    @State private var isPressed = false
    static var lastRefreshModelsTime: Date = .init(timeIntervalSince1970: 0)

    init() {
        self.updateCurrentModel()
    }

    var models: [LLMModel] {
        CopilotModelManager.getAvailableChatLLMs()
    }

    func updateCurrentModel() {
        selectedModel = AppState.shared.getSelectedModelName() ?? defaultModel.modelName
    }

    var body: some View {
        WithPerceptionTracking {
            Menu(selectedModel) {
                if models.isEmpty {
                    Button {
                        // No action needed
                    } label: {
                        Text("Loading...")
                    }
                } else {
                    ForEach(models, id: \.self) { option in
                        Button {
                            selectedModel = option.modelName
                            AppState.shared.setSelectedModel(option)
                        } label: {
                            if selectedModel == option.modelName {
                                Text("✓ \(option.modelName)")
                            } else {
                                Text("    \(option.modelName)")
                            }
                        }
                    }
                }
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: labelWidth())
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .onAppear() {
                updateCurrentModel()
                Task {
                    await refreshModels()
                }
            }
            .help("Pick Model")
        }
    }

    func labelWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let width = selectedModel.size(withAttributes: attributes).width
        return CGFloat(width + 20)
    }

    @MainActor
    func refreshModels() async {
        let now = Date()
        if now.timeIntervalSince(Self.lastRefreshModelsTime) < 60 {
            return
        }

        Self.lastRefreshModelsTime = now
        let copilotModels = await SharedChatService.shared.copilotModels()
        if !copilotModels.isEmpty {
            CopilotModelManager.updateLLMs(copilotModels)
        }
    }
}

struct ModelPicker_Previews: PreviewProvider {
    static var previews: some View {
        ModelPicker()
    }
}
