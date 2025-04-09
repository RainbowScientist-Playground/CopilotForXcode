import ActiveApplicationMonitor
import ConversationTab
import AppKit
import ChatTab
import ComposableArchitecture
import SwiftUI
import SharedUIComponents
import GitHubCopilotViewModel
import Status

private let r: Double = 8

struct ChatWindowView: View {
    let store: StoreOf<ChatPanelFeature>
    let toggleVisibility: (Bool) -> Void
    @State private var isChatHistoryVisible: Bool = false
    @ObservedObject private var statusObserver = StatusObserver.shared

    var body: some View {
        WithPerceptionTracking {
            let _ = store.currentChatWorkspace?.selectedTabId // force re-evaluation
            ZStack {
                if statusObserver.observedAXStatus == .notGranted {
                    ChatNoAXPermissionView()
                } else {
                    switch statusObserver.authStatus.status {
                    case .loggedIn:
                        if isChatHistoryVisible {
                            ChatHistoryViewWrapper(store: store, isChatHistoryVisible: $isChatHistoryVisible)
                        } else {
                            ChatView(store: store, isChatHistoryVisible: $isChatHistoryVisible)
                        }
                    case .notLoggedIn:
                        ChatLoginView(viewModel: GitHubCopilotViewModel.shared)
                    case .notAuthorized:
                        ChatNoSubscriptionView(viewModel: GitHubCopilotViewModel.shared)
                    default:
                        ChatLoadingView()
                    }
                }
            }
            .onChange(of: store.isPanelDisplayed) { isDisplayed in
                toggleVisibility(isDisplayed)
            }
            .preferredColorScheme(store.colorScheme)
        }
    }
}

struct ChatView: View {
    let store: StoreOf<ChatPanelFeature>
    @Binding var isChatHistoryVisible: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.regularMaterial).frame(height: 28)

            Divider()

            ZStack {
                VStack(spacing: 0) {
                    ChatBar(store: store, isChatHistoryVisible: $isChatHistoryVisible)
                        .frame(height: 32)
                        .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    ChatTabContainer(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .xcodeStyleFrame(cornerRadius: 10)
        .ignoresSafeArea(edges: .top)
    }
}

struct ChatHistoryViewWrapper: View {
    let store: StoreOf<ChatPanelFeature>
    @Binding var isChatHistoryVisible: Bool

    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                Rectangle().fill(.regularMaterial).frame(height: 28)

                Divider()
                
                ChatHistoryView(
                    store: store,
                    isChatHistoryVisible: $isChatHistoryVisible
                )
                .background(Color(nsColor: .windowBackgroundColor))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .xcodeStyleFrame(cornerRadius: 10)
            .ignoresSafeArea(edges: .top)
            .preferredColorScheme(store.colorScheme)
            .focusable()
            .onExitCommand(perform: {
                isChatHistoryVisible = false
            })
        }
    }
}

struct ChatLoadingView: View {
    var body: some View {
        VStack(alignment: .center) {
            
            Spacer()
            
            VStack(spacing: 24) {
                Instruction()
                
                ProgressView("Loading...")
                    
            }
            .frame(maxWidth: .infinity, alignment: .center)
            // keep same as chat view
            .padding(.top, 20) // chat bar
            
            Spacer()

        }
        .xcodeStyleFrame(cornerRadius: 10)
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ChatTitleBar: View {
    let store: StoreOf<ChatPanelFeature>
    @State var isHovering = false

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 6) {
                Button(action: {
                    store.send(.closeActiveTabClicked)
                }) {
                    EmptyView()
                }
                .opacity(0)
                .keyboardShortcut("w", modifiers: [.command])

                Button(
                    action: {
                        store.send(.hideButtonClicked)
                    }
                ) {
                    Image(systemName: "minus")
                        .foregroundStyle(.black.opacity(0.5))
                        .font(Font.system(size: 8).weight(.heavy))
                }
                .opacity(0)
                .keyboardShortcut("m", modifiers: [.command])

                Spacer()

                TrafficLightButton(
                    isHovering: isHovering,
                    isActive: store.isDetached,
                    color: Color(nsColor: .systemCyan),
                    action: {
                        store.send(.toggleChatPanelDetachedButtonClicked)
                    }
                ) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.black.opacity(0.5))
                        .font(Font.system(size: 6).weight(.black))
                        .transformEffect(.init(translationX: 0, y: 0.5))
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .onHover(perform: { hovering in
                isHovering = hovering
            })
        }
    }

    struct TrafficLightButton<Icon: View>: View {
        let isHovering: Bool
        let isActive: Bool
        let color: Color
        let action: () -> Void
        let icon: () -> Icon

        @Environment(\.controlActiveState) var controlActiveState

        var body: some View {
            Button(action: {
                action()
            }) {
                Circle()
                    .fill(
                        controlActiveState == .key && isActive
                            ? color
                            : Color(nsColor: .separatorColor)
                    )
                    .frame(
                        width: Style.trafficLightButtonSize,
                        height: Style.trafficLightButtonSize
                    )
                    .overlay {
                        Circle().stroke(lineWidth: 0.5).foregroundColor(.black.opacity(0.2))
                    }
                    .overlay {
                        if isHovering {
                            icon()
                        }
                    }
            }
            .focusable(false)
        }
    }
}

private extension View {
    func hideScrollIndicator() -> some View {
        if #available(macOS 13.0, *) {
            return scrollIndicators(.hidden)
        } else {
            return self
        }
    }
}

struct ChatBar: View {
    let store: StoreOf<ChatPanelFeature>
    @Binding var isChatHistoryVisible: Bool

    struct TabBarState: Equatable {
        var tabInfo: IdentifiedArray<String, ChatTabInfo>
        var selectedTabId: String
    }

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 0) {
                if let name = store.chatHistory.selectedWorkspaceName {
                    ChatWindowHeader(store: store)
                }

                Spacer()

                CreateButton(store: store)

                ChatHistoryButton(store: store, isChatHistoryVisible: $isChatHistoryVisible)
            }
            .padding(.horizontal, 12)
        }
    }

    struct Tabs: View {
        let store: StoreOf<ChatPanelFeature>
        @Environment(\.chatTabPool) var chatTabPool

        var body: some View {
            WithPerceptionTracking {
                let tabInfo = store.currentChatWorkspace?.tabInfo
                let selectedTabId = store.currentChatWorkspace?.selectedTabId
                ?? store.currentChatWorkspace?.tabInfo.first?.id
                    ?? ""
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(tabInfo!, id: \.id) { info in
                                if let tab = chatTabPool.getTab(of: info.id) {
                                    ChatTabBarButton(
                                        store: store,
                                        info: info,
                                        content: { tab.tabItem },
                                        icon: { tab.icon },
                                        isSelected: info.id == selectedTabId
                                    )
                                    .contextMenu {
                                        tab.menu
                                    }
                                    .id(info.id)
                                } else {
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .hideScrollIndicator()
                    .onChange(of: selectedTabId) { id in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id)
                        }
                    }
                }
            }
        }
    }

    struct ChatWindowHeader: View {
        let store: StoreOf<ChatPanelFeature>

        var body: some View {
            WithPerceptionTracking {
                HStack(spacing: 0) {
                    Image("XcodeIcon")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 24, height: 24)

                    Text(store.chatHistory.selectedWorkspaceName!)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.leading, 4)
                        .truncationMode(.tail)
                        .frame(maxWidth: 192, alignment: .leading)
                        .help(store.chatHistory.selectedWorkspacePath!)
                }
            }
        }
    }

    struct CreateButton: View {
        let store: StoreOf<ChatPanelFeature>

        var body: some View {
            WithPerceptionTracking {
                Button(action: {
                    store.send(.createNewTapButtonClicked(kind: nil))
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(HoverButtonStyle())
                .padding(.horizontal, 4)
                .help("New Chat")
            }
        }
    }
    
    struct ChatHistoryButton: View {
        let store: StoreOf<ChatPanelFeature>
        @Binding var isChatHistoryVisible: Bool
        
        var body: some View {
            WithPerceptionTracking {
                Button(action: {
                    isChatHistoryVisible = true
                }) {
                    Image("HistoryIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                }
                .buttonStyle(HoverButtonStyle(padding: -2))
                .help("Show Chats...")
                .accessibilityLabel("Show Chats...")
            }
        }
    }
}

struct ChatTabBarButton<Content: View, Icon: View>: View {
    let store: StoreOf<ChatPanelFeature>
    let info: ChatTabInfo
    let content: () -> Content
    let icon: () -> Icon
    let isSelected: Bool
    @State var isHovered: Bool = false

    var body: some View {
        if self.isSelected {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    icon()
                        .buttonStyle(.plain)
                }
                .font(.callout)
                .lineLimit(1)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

struct ChatTabContainer: View {
    let store: StoreOf<ChatPanelFeature>
    @Environment(\.chatTabPool) var chatTabPool

    var body: some View {
        WithPerceptionTracking {
            let tabInfo = store.currentChatWorkspace?.tabInfo
            let selectedTabId = store.currentChatWorkspace?.selectedTabId
                ?? store.currentChatWorkspace?.tabInfo.first?.id
                ?? ""

            ZStack {
                if tabInfo == nil || tabInfo!.isEmpty {
                    Text("Empty")
                } else {
                    ForEach(tabInfo!) { tabInfo in
                        if let tab = chatTabPool.getTab(of: tabInfo.id) {
                            let isActive = tab.id == selectedTabId
                            tab.body
                                .opacity(isActive ? 1 : 0)
                                .disabled(!isActive)
                                .allowsHitTesting(isActive)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                // move it out of window
                                .rotationEffect(
                                    isActive ? .zero : .degrees(90),
                                    anchor: .topLeading
                                )
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

struct CreateOtherChatTabMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "chevron.down")
            .resizable()
            .frame(width: 7, height: 4)
            .frame(maxHeight: .infinity)
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .foregroundColor(.secondary)
    }
}

struct ChatWindowView_Previews: PreviewProvider {
    static let pool = ChatTabPool([
        "2": EmptyChatTab(id: "2"),
        "3": EmptyChatTab(id: "3"),
        "4": EmptyChatTab(id: "4"),
        "5": EmptyChatTab(id: "5"),
        "6": EmptyChatTab(id: "6"),
        "7": EmptyChatTab(id: "7"),
    ])

    static func createStore() -> StoreOf<ChatPanelFeature> {
        StoreOf<ChatPanelFeature>(
            initialState: .init(
                chatHistory: .init(
                    workspaces: [
                        .init(
                            id: .init(path: "p", username: "u"),
                            tabInfo: [
                                .init(id: "2", title: "Empty-2", workspacePath: "path", username: "username"),
                                .init(id: "3", title: "Empty-3", workspacePath: "path", username: "username"),
                                .init(id: "4", title: "Empty-4", workspacePath: "path", username: "username"),
                                .init(id: "5", title: "Empty-5", workspacePath: "path", username: "username"),
                                .init(id: "6", title: "Empty-6", workspacePath: "path", username: "username"),
                                .init(id: "7", title: "Empty-7", workspacePath: "path", username: "username"),
                            ] as IdentifiedArray<String, ChatTabInfo>,
                            selectedTabId: "2"
                        )
                    ] as IdentifiedArray<WorkspaceIdentifier, ChatWorkspace>,
                    selectedWorkspacePath: "activeWorkspacePath",
                    selectedWorkspaceName: "activeWorkspacePath"
                ),
                isPanelDisplayed: true
            ),
            reducer: { ChatPanelFeature() }
        )
    }

    static var previews: some View {
        ChatWindowView(store: createStore(), toggleVisibility: { _ in })
            .xcodeStyleFrame()
            .padding()
            .environment(\.chatTabPool, pool)
    }
}

struct ChatLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ChatLoadingView()
    }
}
