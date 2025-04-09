import Combine
import Foundation
import JSONRPC
import LanguageServerProtocol
import Logger

public enum ProgressKind: String {
    case begin, report, end
}

public protocol ConversationProgressHandler {
    var onBegin: PassthroughSubject<(String, ConversationProgressBegin), Never> { get }
    var onProgress: PassthroughSubject<(String, ConversationProgressReport), Never> { get }
    var onEnd: PassthroughSubject<(String, ConversationProgressEnd), Never> { get }
    func handleConversationProgress(_ progressParams: ProgressParams)
}

public final class ConversationProgressHandlerImpl: ConversationProgressHandler {
    public static let shared = ConversationProgressHandlerImpl()

    public var onBegin = PassthroughSubject<(String, ConversationProgressBegin), Never>()
    public var onProgress = PassthroughSubject<(String, ConversationProgressReport), Never>()
    public var onEnd = PassthroughSubject<(String, ConversationProgressEnd), Never>()

    private var cancellables = Set<AnyCancellable>()

    public func handleConversationProgress(_ progressParams: ProgressParams) {
        guard let token = getValueAsString(from: progressParams.token),
              let data = try? JSONEncoder().encode(progressParams.value) else {
            print("Error encountered while parsing conversation progress params")
            Logger.gitHubCopilot.error("Error encountered while parsing conversation progress params")
            return
        }

        let progress = try? JSONDecoder().decode(ConversationProgressContainer.self, from: data)
        switch progress {
        case .begin(let begin):
            onBegin.send((token, begin))
        case .report(let report):
            onProgress.send((token, report))
        case .end(let end):
            onEnd.send((token, end))
        default:
            print("Invalid progress kind")
            return
        }
}

    private func getValueAsString(from token: ProgressToken) -> String? {
        switch token {
        case .optionA(let intValue):
            return String(intValue)
        case .optionB(let stringValue):
            return stringValue
        }
    }
}
