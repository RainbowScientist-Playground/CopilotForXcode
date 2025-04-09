import ActiveApplicationMonitor
import AppActivator
import AppKit
import ConversationTab
import ChatTab
import ComposableArchitecture
import Dependencies
import Preferences
import SuggestionBasic
import SuggestionWidget
import PersistMiddleware
import ChatService

#if canImport(ChatTabPersistent)
import ChatTabPersistent
#endif

@Reducer
struct GUI {
    @ObservableState
    struct State: Equatable {
        var suggestionWidgetState = WidgetFeature.State()

        var chatHistory: ChatHistory {
            get { suggestionWidgetState.chatPanelState.chatHistory }
            set { suggestionWidgetState.chatPanelState.chatHistory = newValue }
        }

        var promptToCodeGroup: PromptToCodeGroup.State {
            get { suggestionWidgetState.panelState.content.promptToCodeGroup }
            set { suggestionWidgetState.panelState.content.promptToCodeGroup = newValue }
        }
    }

    enum Action {
        case start
        case openChatPanel(forceDetach: Bool)
        case createAndSwitchToChatTabIfNeeded
//        case createAndSwitchToBrowserTabIfNeeded(url: URL)
        case sendCustomCommandToActiveChat(CustomCommand)
        case toggleWidgetsHotkeyPressed

        case suggestionWidget(WidgetFeature.Action)
        case switchWorkspace(path: String, name: String, username: String)
        case initWorkspaceChatTabIfNeeded(path: String, username: String)

        static func promptToCodeGroup(_ action: PromptToCodeGroup.Action) -> Self {
            .suggestionWidget(.panel(.sharedPanel(.promptToCodeGroup(action))))
        }

        #if canImport(ChatTabPersistent)
        case persistent(ChatTabPersistent.Action)
        #endif
    }

    @Dependency(\.chatTabPool) var chatTabPool
    @Dependency(\.activateThisApp) var activateThisApp

    public enum Debounce: Hashable {
        case updateChatTabOrder
    }

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.suggestionWidgetState, action: \.suggestionWidget) {
                WidgetFeature()
            }

            Scope(
                state: \.chatHistory,
                action: \.suggestionWidget.chatPanel
            ) {
                Reduce { state, action in
                    switch action {
                    case let .createNewTapButtonClicked(kind):
//                        return .run { send in
//                            if let (_, chatTabInfo) = await chatTabPool.createTab(for: kind) {
//                                await send(.createNewTab(chatTabInfo))
//                            }
//                        }
                        // The chat workspace should exist before create tab
                        guard let currentChatWorkspace = state.currentChatWorkspace else { return .none }
                        
                        return .run { send in
                            if let (_, chatTabInfo) = await chatTabPool.createTab(for: kind, with: currentChatWorkspace) {
                                await send(.appendAndSelectTab(chatTabInfo))
                            }
                        }

//                    case let .closeTabButtonClicked(id):
//                        return .run { _ in
//                            chatTabPool.removeTab(of: id)
//                        }

                    case let .chatTab(_, .openNewTab(builder)):
                        // The chat workspace should exist before create tab
                        guard let currentChatWorkspace = state.currentChatWorkspace else { return .none }
                        return .run { send in
                            if let (_, chatTabInfo) = await chatTabPool
                                .createTab(from: builder.chatTabBuilder, with: currentChatWorkspace)
                            {
                                await send(.appendAndSelectTab(chatTabInfo))
                            }
                        }

                    default:
                        return .none
                    }
                }
            }

            #if canImport(ChatTabPersistent)
            Scope(state: \.persistentState, action: \.persistent) {
                ChatTabPersistent()
            }
            #endif

            Reduce { state, action in
                switch action {
                case .start:
                    #if canImport(ChatTabPersistent)
                    return .run { send in
                        await send(.persistent(.restoreChatTabs))
                    }
                    #else
                    return .none
                    #endif

                case let .openChatPanel(forceDetach):
                    return .run { send in
                        await send(
                            .suggestionWidget(
                                .chatPanel(.presentChatPanel(forceDetach: forceDetach))
                            )
                        )
                        await send(.suggestionWidget(.updateKeyWindow(.chatPanel)))

                        activateThisApp()
                    }

                case .createAndSwitchToChatTabIfNeeded:
                    // The chat workspace should exist before create tab
                    guard let currentChatWorkspace = state.chatHistory.currentChatWorkspace else { return .none }
                    
                    if let selectedTabInfo = currentChatWorkspace.selectedTabInfo,
                       chatTabPool.getTab(of: selectedTabInfo.id) is ConversationTab
                    {
                        // Already in Chat tab
                        return .none
                    }

                    if let firstChatTabInfo = state.chatHistory.currentChatWorkspace?.tabInfo.first(where: {
                        chatTabPool.getTab(of: $0.id) is ConversationTab
                    }) {
                        return .run { send in
                            await send(.suggestionWidget(.chatPanel(.tabClicked(
                                id: firstChatTabInfo.id
                            ))))
                        }
                    }
                    return .run { send in
                        if let (_, chatTabInfo) = await chatTabPool.createTab(for: nil, with: currentChatWorkspace) {
                            await send(
                                .suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo)))
                            )
                        }
                    }

                case let .switchWorkspace(path, name, username):
                    return .run { send in
                        await send(
                            .suggestionWidget(.chatPanel(.switchWorkspace(path, name, username)))
                        )
                    }
                case let .initWorkspaceChatTabIfNeeded(path, username):
                    let identifier = WorkspaceIdentifier(path: path, username: username)
                    guard let chatWorkspace = state.chatHistory.workspaces[id: identifier], chatWorkspace.tabInfo.isEmpty
                            else { return .none }
                    return .run { send in
                        if let (_, chatTabInfo) = await chatTabPool.createTab(for: nil, with: chatWorkspace) {
                            await send(
                                .suggestionWidget(.chatPanel(.appendTabToWorkspace(chatTabInfo, chatWorkspace)))
                                )
                        }
                    }
//                case let .createAndSwitchToBrowserTabIfNeeded(url):
//                    #if canImport(BrowserChatTab)
//                    func match(_ tabURL: URL?) -> Bool {
//                        guard let tabURL else { return false }
//                        return tabURL == url
//                            || tabURL.absoluteString.hasPrefix(url.absoluteString)
//                    }
//
//                    if let selectedTabInfo = state.chatTabGroup.selectedTabInfo,
//                       let tab = chatTabPool.getTab(of: selectedTabInfo.id) as? BrowserChatTab,
//                       match(tab.url)
//                    {
//                        // Already in the target Browser tab
//                        return .none
//                    }
//
//                    if let firstChatTabInfo = state.chatTabGroup.tabInfo.first(where: {
//                        guard let tab = chatTabPool.getTab(of: $0.id) as? BrowserChatTab,
//                              match(tab.url)
//                        else { return false }
//                        return true
//                    }) {
//                        return .run { send in
//                            await send(.suggestionWidget(.chatPanel(.tabClicked(
//                                id: firstChatTabInfo.id
//                            ))))
//                        }
//                    }
//
//                    return .run { send in
//                        if let (_, chatTabInfo) = await chatTabPool.createTab(
//                            for: .init(BrowserChatTab.urlChatBuilder(
//                                url: url,
//                                externalDependency: ChatTabFactory
//                                    .externalDependenciesForBrowserChatTab()
//                            ))
//                        ) {
//                            await send(
//                                .suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo)))
//                            )
//                        }
//                    }
//
//                    #else
//                    return .none
//                    #endif

                case let .sendCustomCommandToActiveChat(command):
                    @Sendable func stopAndHandleCommand(_ tab: ConversationTab) async {
                        if tab.service.isReceivingMessage {
                            await tab.service.stopReceivingMessage()
                        }
                        try? await tab.service.handleCustomCommand(command)
                    }
                    
                    guard var currentChatWorkspace = state.chatHistory.currentChatWorkspace else { return .none }

                    if let info = currentChatWorkspace.selectedTabInfo,
                       let activeTab = chatTabPool.getTab(of: info.id) as? ConversationTab
                    {
                        return .run { send in
                            await send(.openChatPanel(forceDetach: false))
                            await stopAndHandleCommand(activeTab)
                        }
                    }

                    let chatWorkspace = currentChatWorkspace
                    if var info = currentChatWorkspace.tabInfo.first(where: {
                        chatTabPool.getTab(of: $0.id) is ConversationTab
                    }),
                        let chatTab = chatTabPool.getTab(of: info.id) as? ConversationTab
                    {
                        let (originalTab, currentTab) = currentChatWorkspace.switchTab(to: &info)
                        let updatedChatWorkspace = currentChatWorkspace
                        
                        return .run { send in
                            await send(.suggestionWidget(.chatPanel(.updateChatHistory(updatedChatWorkspace))))
                            await send(.openChatPanel(forceDetach: false))
                            await stopAndHandleCommand(chatTab)
                            await send(.suggestionWidget(.chatPanel(.saveChatTabInfo([originalTab, currentTab], chatWorkspace))))
                        }
                    }

                    return .run { send in
                        guard let (chatTab, chatTabInfo) = await chatTabPool.createTab(for: nil, with: chatWorkspace)
                        else {
                            return
                        }
                        await send(.suggestionWidget(.chatPanel(.appendAndSelectTab(chatTabInfo))))
                        await send(.openChatPanel(forceDetach: false))
                        if let chatTab = chatTab as? ConversationTab {
                            await stopAndHandleCommand(chatTab)
                        }
                    }

                case .toggleWidgetsHotkeyPressed:
                    return .run { send in
                        await send(.suggestionWidget(.circularWidget(.widgetClicked)))
                    }

                case let .suggestionWidget(.chatPanel(.chatTab(id, .tabContentUpdated))):
                    #if canImport(ChatTabPersistent)
                    // when a tab is updated, persist it.
                    return .run { send in
                        await send(.persistent(.chatTabUpdated(id: id)))
                    }
                    #else
                    return .none
                    #endif

//                case let .suggestionWidget(.chatPanel(.closeTabButtonClicked(id))):
//                    #if canImport(ChatTabPersistent)
//                    // when a tab is closed, remove it from persistence.
//                    return .run { send in
//                        await send(.persistent(.chatTabClosed(id: id)))
//                    }
//                    #else
//                    return .none
//                    #endif

                case .suggestionWidget:
                    return .none

                #if canImport(ChatTabPersistent)
                case .persistent:
                    return .none
                #endif
                }
            }
        }
//        .onChange(of: \.chatCollection.selectedChatGroup?.tabInfo) { old, new in
//            Reduce { _, _ in
//                guard old.map(\.id) != new.map(\.id) else {
//                    return .none
//                }
//                #if canImport(ChatTabPersistent)
//                return .run { send in
//                    await send(.persistent(.chatOrderChanged))
//                }.debounce(id: Debounce.updateChatTabOrder, for: 1, scheduler: DispatchQueue.main)
//                #else
//                return .none
//                #endif
//            }
//        }
    }
}

@MainActor
public final class GraphicalUserInterfaceController {
    let store: StoreOf<GUI>
    let widgetController: SuggestionWidgetController
    let widgetDataSource: WidgetDataSource
    let chatTabPool: ChatTabPool
    
    // Used for restoring. Handle concurrency
    var restoredChatHistory: Set<WorkspaceIdentifier> = Set()

    class WeakStoreHolder {
        weak var store: StoreOf<GUI>?
    }

    init() {
        let chatTabPool = ChatTabPool()
        let suggestionDependency = SuggestionWidgetControllerDependency()
        let setupDependency: (inout DependencyValues) -> Void = { dependencies in
            dependencies.suggestionWidgetControllerDependency = suggestionDependency
            dependencies.suggestionWidgetUserDefaultsObservers = .init()
            dependencies.chatTabPool = chatTabPool
            dependencies.chatTabBuilderCollection = ChatTabFactory.chatTabBuilderCollection
            dependencies.promptToCodeAcceptHandler = { promptToCode in
                Task {
                    let handler = PseudoCommandHandler()
                    await handler.acceptPromptToCode()
                    if !promptToCode.isContinuous {
                        NSWorkspace.activatePreviousActiveXcode()
                    } else {
                        NSWorkspace.activateThisApp()
                    }
                }
            }
        }
        let store = StoreOf<GUI>(
            initialState: .init(),
            reducer: { GUI() },
            withDependencies: setupDependency
        )
        self.store = store
        self.chatTabPool = chatTabPool
        widgetDataSource = .init()

        widgetController = SuggestionWidgetController(
            store: store.scope(
                state: \.suggestionWidgetState,
                action: \.suggestionWidget
            ),
            chatTabPool: chatTabPool,
            dependency: suggestionDependency
        )

        chatTabPool.createStore = { info in
            store.scope(
                state: { state in
                    state.chatHistory.currentChatWorkspace?.tabInfo[id: info.id] ?? info
                },
                action: { childAction in
                    .suggestionWidget(.chatPanel(.chatTab(id: info.id, action: childAction)))
                }
            )
        }

        suggestionDependency.suggestionWidgetDataSource = widgetDataSource
        suggestionDependency.onOpenChatClicked = { [weak self] in
            Task { [weak self] in
                await self?.store.send(.createAndSwitchToChatTabIfNeeded).finish()
                self?.store.send(.openChatPanel(forceDetach: false))
            }
        }
        suggestionDependency.onCustomCommandClicked = { command in
            Task {
                let commandHandler = PseudoCommandHandler()
                await commandHandler.handleCustomCommand(command)
            }
        }
    }

    func start() {
        store.send(.start)
    }

    public func openGlobalChat() {
        PseudoCommandHandler().openChat(forceDetach: true)
    }
}

extension ChatTabPool {
    @MainActor
    func createTab(
        id: String = UUID().uuidString,
        from builder: ChatTabBuilder,
        with chatWorkspace: ChatWorkspace
    ) async -> (any ChatTab, ChatTabInfo)? {
        let id = id
        let info = ChatTabInfo(id: id, workspacePath: chatWorkspace.workspacePath, username: chatWorkspace.username)
        guard let chatTab = await builder.build(store: createStore(info)) else { return nil }
        setTab(chatTab)
        return (chatTab, info)
    }

    @MainActor
    func createTab(
        for kind: ChatTabKind?,
        with chatWorkspace: ChatWorkspace
    ) async -> (any ChatTab, ChatTabInfo)? {
        let id = UUID().uuidString
        let info = ChatTabInfo(id: id, workspacePath: chatWorkspace.workspacePath, username: chatWorkspace.username)
        guard let builder = kind?.builder else {
            let chatTab = ConversationTab(store: createStore(info), with: info)
            setTab(chatTab)
            return (chatTab, info)
        }
        
        guard let chatTab = await builder.build(store: createStore(info)) else { return nil }
        setTab(chatTab)
        return (chatTab, info)
    }
}


extension GraphicalUserInterfaceController {
    
    @MainActor
    public func restore(path workspacePath: String, name workspaceName: String, username: String) async -> Void {
        let workspaceIdentifier = WorkspaceIdentifier(path: workspacePath, username: username)
        guard !restoredChatHistory.contains(workspaceIdentifier) else { return }
        
        // only restore once regardless of success or fail
        restoredChatHistory.insert(workspaceIdentifier)
        
        let storedChatTabInfos = ChatTabInfoStore.getAll(with: .init(workspacePath: workspacePath, username: username))
        if storedChatTabInfos.count > 0
        {
            var tabInfo: IdentifiedArray<String, ChatTabInfo> = []
            for info in storedChatTabInfos {
                tabInfo[id: info.id] = info
                let chatTab = ConversationTab.restoreConversation(by: info, store: chatTabPool.createStore(info))
                chatTabPool.setTab(chatTab)
            }
            
            let chatWorkspace = ChatWorkspace(
                id: .init(path: workspacePath, username: username),
                tabInfo: tabInfo,
                tabCollection: [],
                selectedTabId: storedChatTabInfos.first(where: { $0.isSelected })?.id
            )
            self.store.send(.suggestionWidget(.chatPanel(.restoreWorkspace(chatWorkspace))))
        }
    }
}
