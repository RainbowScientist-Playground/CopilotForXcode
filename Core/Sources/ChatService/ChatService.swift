import ChatAPIService
import Combine
import Foundation
import GitHubCopilotService
import Preferences
import ConversationServiceProvider
import BuiltinExtension
import JSONRPC
import Status
import Persist
import PersistMiddleware
import ChatTab
import Logger
import Workspace
import XcodeInspector

public protocol ChatServiceType {
    var memory: ContextAwareAutoManagedChatMemory { get set }
    func send(_ id: String, content: String, skillSet: [ConversationSkill], references: [FileReference], model: String?) async throws
    func stopReceivingMessage() async
    func upvote(_ id: String, _ rating: ConversationRating) async
    func downvote(_ id: String, _ rating: ConversationRating) async
    func copyCode(_ id: String) async
}

public final class ChatService: ChatServiceType, ObservableObject {
    
    public var memory: ContextAwareAutoManagedChatMemory
    @Published public internal(set) var chatHistory: [ChatMessage] = []
    @Published public internal(set) var isReceivingMessage = false
    private let chatTabInfo: ChatTabInfo
    private let conversationProvider: ConversationServiceProvider?
    private let conversationProgressHandler: ConversationProgressHandler
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    // sync all the files in the workspace to watch for changes.
    private let watchedFilesHandler: WatchedFilesHandler = WatchedFilesHandlerImpl.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeRequestId: String?
    private(set) public var conversationId: String?
    private var skillSet: [ConversationSkill] = []
    private var isRestored: Bool = false
    init(provider: any ConversationServiceProvider,
         memory: ContextAwareAutoManagedChatMemory = ContextAwareAutoManagedChatMemory(),
         conversationProgressHandler: ConversationProgressHandler = ConversationProgressHandlerImpl.shared,
         chatTabInfo: ChatTabInfo) {
        self.memory = memory
        self.conversationProvider = provider
        self.conversationProgressHandler = conversationProgressHandler
        self.chatTabInfo = chatTabInfo
        memory.chatService = self
        
        subscribeToNotifications()
        subscribeToConversationContextRequest()
        subscribeToWatchedFilesHandler()
    }
    
    private func subscribeToNotifications() {
        memory.observeHistoryChange { [weak self] in
            Task { [weak self] in
                guard let memory = self?.memory else { return }
                self?.chatHistory = await memory.history
            }
        }
        
        conversationProgressHandler.onBegin.sink { [weak self] (token, progress) in
            self?.handleProgressBegin(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onProgress.sink { [weak self] (token, progress) in
            self?.handleProgressReport(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onEnd.sink { [weak self] (token, progress) in
            self?.handleProgressEnd(token: token, progress: progress)
        }.store(in: &cancellables)
    }
    
    private func subscribeToConversationContextRequest() {
        self.conversationContextHandler.onConversationContext.sink(receiveValue: { [weak self] (request, completion) in
            guard let skills = self?.skillSet, !skills.isEmpty, request.params!.conversationId == self?.conversationId else { return }
            skills.forEach { skill in
                if (skill.applies(params: request.params!)) {
                    skill.resolveSkill(request: request, completion: completion)
                }
            }
        }).store(in: &cancellables)
    }
    
    private func subscribeToWatchedFilesHandler() {
        self.watchedFilesHandler.onWatchedFiles.sink(receiveValue: { [weak self] (request, completion) in
            guard let self, request.params!.workspaceUri != "/" else { return }
            self.startFileChangeWatcher()
        }).store(in: &cancellables)
    }
    
    public static func service(for chatTabInfo: ChatTabInfo) -> ChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return ChatService(provider: provider, chatTabInfo: chatTabInfo)
    }
    
    // this will be triggerred in conversation tab if needed
    public func restoreIfNeeded() {
        guard self.isRestored == false else { return }
        
        Task {
            let storedChatMessages = fetchAllChatMessagesFromStorage()
            await mutateHistory { history in
                history.append(contentsOf: storedChatMessages)
            }
        }
        
        self.isRestored = true
    }
    
    public func send(_ id: String, content: String, skillSet: Array<ConversationSkill>, references: Array<FileReference>, model: String? = nil) async throws {
        guard activeRequestId == nil else { return }
        let workDoneToken = UUID().uuidString
        activeRequestId = workDoneToken
        
        let chatMessage = ChatMessage(
            id: id,
            chatTabID: self.chatTabInfo.id,
            role: .user,
            content: content,
            references: references.toConversationReferences()
        )
        await memory.appendMessage(chatMessage)
        
        // persist
        saveChatMessageToStorage(chatMessage)
        
        if content.hasPrefix("/releaseNotes") {
            if let fileURL = Bundle.main.url(forResource: "ReleaseNotes", withExtension: "md"),
                let whatsNewContent = try? String(contentsOf: fileURL)
            {
                // will be persist in resetOngoingRequest()
                // there is no turn id from CLS, just set it as id
                let clsTurnID = UUID().uuidString
                let progressMessage = ChatMessage(
                    id: clsTurnID,
                    chatTabID: self.chatTabInfo.id,
                    clsTurnID: clsTurnID,
                    role: .assistant,
                    content: whatsNewContent,
                    references: []
                )
                await memory.appendMessage(progressMessage)
            }
            resetOngoingRequest()
            return
        }
        
        let skillCapabilities: [String] = [ CurrentEditorSkill.ID, ProblemsInActiveDocumentSkill.ID ]
        let supportedSkills: [String] = skillSet.map { $0.id }
        let ignoredSkills: [String] = skillCapabilities.filter {
            !supportedSkills.contains($0)
        }
        
        /// replace the `@workspace` to `@project`
        let newContent = replaceFirstWord(in: content, from: "@workspace", to: "@project")
        
        let request = ConversationRequest(workDoneToken: workDoneToken,
                                          content: newContent,
                                          workspaceFolder: "",
                                          skills: skillCapabilities,
                                          ignoredSkills: ignoredSkills,
                                          references: references,
                                          model: model)
        self.skillSet = skillSet
        try await send(request)
    }

    public func sendAndWait(_ id: String, content: String) async throws -> String {
        try await send(id, content: content, skillSet: [], references: [])
        if let reply = await memory.history.last(where: { $0.role == .assistant })?.content {
            return reply
        }
        return ""
    }

    public func stopReceivingMessage() async {
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId)
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        resetOngoingRequest()
    }

    public func clearHistory() async {
        let messageIds = await memory.history.map { $0.id }
        
        await memory.clearHistory()
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId)
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        
        deleteAllChatMessagesFromStorage(messageIds)
        resetOngoingRequest()
    }

    public func deleteMessage(id: String) async {
        await memory.removeMessage(id)
        deleteChatMessageFromStorage(id)
    }

    // Not used for now
    public func resendMessage(id: String) async throws {
        if let message = (await memory.history).first(where: { $0.id == id })
        {
            do {
                try await send(id, content: message.content, skillSet: [], references: [])
            } catch {
                print("Failed to resend message")
            }
        }
    }

    public func setMessageAsExtraPrompt(id: String) async {
        if let message = (await memory.history).first(where: { $0.id == id })
        {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: message.content
                )
                
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await memory.mutateHistory(mutator)
    }

    public func handleCustomCommand(_ command: CustomCommand) async throws {
        struct CustomCommandInfo {
            var specifiedSystemPrompt: String?
            var extraSystemPrompt: String?
            var sendingMessageImmediately: String?
            var name: String?
        }

        let info: CustomCommandInfo? = {
            switch command.feature {
            case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
                let updatePrompt = useExtraSystemPrompt ?? true
                return .init(
                    extraSystemPrompt: updatePrompt ? extraSystemPrompt : nil,
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case let .customChat(systemPrompt, prompt):
                return .init(
                    specifiedSystemPrompt: systemPrompt,
                    extraSystemPrompt: "",
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case .promptToCode: return nil
            case .singleRoundDialog: return nil
            }
        }()

        guard let info else { return }

        let templateProcessor = CustomCommandTemplateProcessor()

        if info.specifiedSystemPrompt != nil || info.extraSystemPrompt != nil {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: ""
                )
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }

        if let sendingMessageImmediately = info.sendingMessageImmediately,
           !sendingMessageImmediately.isEmpty
        {
            try await send(UUID().uuidString, content: templateProcessor.process(sendingMessageImmediately), skillSet: [], references: [])
        }
    }
    
    public func upvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating)
    }
    
    public func downvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating)
    }
    
    public func copyCode(_ id: String) async {
        // TODO: pass copy code info to Copilot server
    }

    // not used
    public func handleSingleRoundDialogCommand(
        systemPrompt: String?,
        overwriteSystemPrompt: Bool,
        prompt: String
    ) async throws -> String {
        let templateProcessor = CustomCommandTemplateProcessor()
        return try await sendAndWait(UUID().uuidString, content: templateProcessor.process(prompt))
    }
    
    private func handleProgressBegin(token: String, progress: ConversationProgressBegin) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        conversationId = progress.conversationId
        
        Task {
            if var lastUserMessage = await memory.history.last(where: { $0.role == .user }) {
                lastUserMessage.clsTurnID = progress.turnId
                saveChatMessageToStorage(lastUserMessage)
            }
        }
    }

    private func handleProgressReport(token: String, progress: ConversationProgressReport) {
        guard let workDownToken = activeRequestId, workDownToken == token else {
            return
        }
        
        let id = progress.turnId
        var content = ""
        var references: [ConversationReference] = []
        var steps: [ConversationProgressStep] = []

        if let reply = progress.reply {
            content = reply
        }
        
        if let progressReferences = progress.references, !progressReferences.isEmpty {
            references = progressReferences.toConversationReferences()
        }
        
        if let progressSteps = progress.steps, !progressSteps.isEmpty {
            steps = progressSteps
        }
        
        if content.isEmpty && references.isEmpty && steps.isEmpty {
            return
        }
        
        // create immutable copies
        let messageContent = content
        let messageReferences = references
        let messageSteps = steps

        Task {
            let message = ChatMessage(
                id: id,
                chatTabID: self.chatTabInfo.id,
                clsTurnID: id,
                role: .assistant,
                content: messageContent,
                references: messageReferences,
                steps: messageSteps
            )

            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
        }
    }

    private func handleProgressEnd(token: String, progress: ConversationProgressEnd) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        let followUp = progress.followUp
        
        if let CLSError = progress.error {
            // CLS Error Code 402: reached monthly chat messages limit
            if CLSError.code == 402 {
                Task {
                    await Status.shared
                        .updateCLSStatus(.error, busy: false, message: CLSError.message)
                    let errorMessage = ChatMessage(
                        id: progress.turnId,
                        chatTabID: self.chatTabInfo.id,
                        clsTurnID: progress.turnId,
                        role: .system,
                        content: CLSError.message
                    )
                    // will persist in resetongoingRequest()
                    await memory.removeMessage(progress.turnId)
                    await memory.appendMessage(errorMessage)
                }
            } else if CLSError.code == 400 && CLSError.message.contains("model is not supported") {
                Task {
                    let errorMessage = ChatMessage(
                        id: progress.turnId,
                        chatTabID: self.chatTabInfo.id,
                        role: .assistant,
                        content: "",
                        errorMessage: "Oops, the model is not supported. Please enable it first in [GitHub Copilot settings](https://github.com/settings/copilot)."
                    )
                    await memory.appendMessage(errorMessage)
                }
            } else {
                Task {
                    let errorMessage = ChatMessage(
                        id: progress.turnId,
                        chatTabID: self.chatTabInfo.id,
                        clsTurnID: progress.turnId,
                        role: .assistant,
                        content: "",
                        errorMessage: CLSError.message
                    )
                    // will persist in resetOngoingRequest()
                    await memory.appendMessage(errorMessage)
                }
            }
            resetOngoingRequest()
            return
        }
        
        Task {
            let message = ChatMessage(
                id: progress.turnId,
                chatTabID: self.chatTabInfo.id,
                clsTurnID: progress.turnId,
                role: .assistant,
                content: "",
                followUp: followUp,
                suggestedTitle: progress.suggestedTitle
            )
            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
        }
        
        resetOngoingRequest()
    }
    
    private func resetOngoingRequest() {
        activeRequestId = nil
        isReceivingMessage = false
        
        
        Task {
            // mark running steps to cancelled
            await mutateHistory({ history in
                guard !history.isEmpty,
                      let lastIndex = history.indices.last,
                      history[lastIndex].role == .assistant else { return }
                
                for i in 0..<history[lastIndex].steps.count {
                    if history[lastIndex].steps[i].status == .running {
                        history[lastIndex].steps[i].status = .cancelled
                    }
                }
            })
            
            // The message of progress report could change rapidly
            // Directly upsert the last chat message of history here
            // Possible repeat upsert, but no harm.
            if let message = await memory.history.last {
                saveChatMessageToStorage(message)
            }
        }
    }
    
    private func send(_ request: ConversationRequest) async throws {
        guard !isReceivingMessage else { throw CancellationError() }
        isReceivingMessage = true
        
        do {
            if let conversationId = conversationId {
                try await conversationProvider?.createTurn(with: conversationId, request: request)
            } else {
                var requestWithTurns = request
                
                var chatHistory = self.chatHistory
                // remove the last user message
                let _ = chatHistory.popLast()
                if chatHistory.count > 0 {
                    // invoke history turns
                    let turns = chatHistory.toTurns()
                    requestWithTurns.turns = turns
                }
                
                try await conversationProvider?.createConversation(requestWithTurns)
            }
        } catch {
            resetOngoingRequest()
            throw error
        }
    }
}


public final class SharedChatService {
    public var chatTemplates: [ChatTemplate]? = nil
    public var chatAgents: [ChatAgent]? = nil
    private let conversationProvider: ConversationServiceProvider?
    
    public static let shared = SharedChatService.service()
    
    init(provider: any ConversationServiceProvider) {
        self.conversationProvider = provider
    }
    
    public static func service() -> SharedChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return SharedChatService(provider: provider)
    }
    
    public func loadChatTemplates() async -> [ChatTemplate]? {
        guard self.chatTemplates == nil else { return self.chatTemplates }

        do {
            if let templates = (try await conversationProvider?.templates()) {
                self.chatTemplates = templates
                return templates
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
    
    public func copilotModels() async -> [CopilotModel] {
        guard let models = try? await conversationProvider?.models() else { return [] }
        return models
    }
    
    public func loadChatAgents() async -> [ChatAgent]? {
        guard self.chatAgents == nil else { return self.chatAgents }
        
        do {
            if let chatAgents = (try await conversationProvider?.agents()) {
                self.chatAgents = chatAgents
                return chatAgents
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
}


extension ChatService {
    
    // do storage operatoin in the background
    private func runInBackground(_ operation: @escaping () -> Void) {
        Task.detached(priority: .utility) {
            operation()
        }
    }
    
    func saveChatMessageToStorage(_ message: ChatMessage) {
        runInBackground {
            ChatMessageStore.save(message, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func deleteChatMessageFromStorage(_ id: String) {
        runInBackground {
                ChatMessageStore.delete(by: id, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    func deleteAllChatMessagesFromStorage(_ ids: [String]) {
        runInBackground {
            ChatMessageStore.deleteAll(by: ids, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func fetchAllChatMessagesFromStorage() -> [ChatMessage] {
        return ChatMessageStore.getAll(by: self.chatTabInfo.id, metadata: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
    }
    
    /// for file change watcher
    func startFileChangeWatcher() {
        Task { [weak self] in
            guard let self else { return }
            let workspaceURL = URL(fileURLWithPath: self.chatTabInfo.workspacePath)
            let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(workspaceURL: workspaceURL, documentURL: nil) ?? workspaceURL
            await FileChangeWatcherServicePool.shared.watch(
                for: workspaceURL
            ) { fileEvents in
                Task { [weak self] in
                    guard let self else { return }
                    try? await self.conversationProvider?.notifyDidChangeWatchedFiles(
                        .init(workspaceUri: projectURL.path, changes: fileEvents),
                        workspace: .init(workspaceURL: workspaceURL, projectURL: projectURL)
                    )
                }
            }
        }
    }
}

func replaceFirstWord(in content: String, from oldWord: String, to newWord: String) -> String {
    let pattern = "^\(oldWord)\\b"
    
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: newWord)
    }
    
    return content
}

extension Array where Element == Reference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            .init(uri: $0.uri, status: .included, kind: .reference($0))
        }
    }
}

extension Array where Element == FileReference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            .init(uri: $0.url.path, status: .included, kind: .fileReference($0))
        }
    }
}
extension [ChatMessage] {
    // transfer chat messages to turns
    // used to restore chat history for CLS
    func toTurns() -> [TurnSchema] {
        var turns: [TurnSchema] = []
        let count = self.count
        var index = 0
        
        while index < count {
            let message = self[index]
            if case .user = message.role {
                var turn = TurnSchema(request: message.content, turnId: message.clsTurnID)
                // has next message
                if index + 1 < count {
                    let nextMessage = self[index + 1]
                    if nextMessage.role == .assistant {
                        turn.response = nextMessage.content
                        index += 1
                    }
                }
                turns.append(turn)
            }
            index += 1
        }
        
        return turns
    }
}
