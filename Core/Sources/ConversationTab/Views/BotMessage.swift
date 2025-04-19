import ComposableArchitecture
import ChatService
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI
import ConversationServiceProvider
import ChatTab
import ChatAPIService

struct BotMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let references: [ConversationReference]
    let followUp: ConversationFollowUp?
    let errorMessage: String?
    let chat: StoreOf<Chat>
    let steps: [ConversationProgressStep]
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize

    @State var isReferencesPresented = false
    
    struct ResponseToolBar: View {
        let id: String
        let chat: StoreOf<Chat>
        let text: String
        
        var body: some View {
            HStack(spacing: 4) {
                
                UpvoteButton { rating in
                    chat.send(.upvote(id, rating))
                }
                
                DownvoteButton { rating in
                    chat.send(.downvote(id, rating))
                }
                
                CopyButton {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    chat.send(.copyCode(id))
                }
                
                Spacer() // Pushes the buttons to the left
            }
        }
    }
    
    struct ReferenceButton: View {
        var r: Double { messageBubbleCornerRadius }
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        
        @Binding var isReferencesPresented: Bool
        
        @State var isReferencesHovered = false
        
        @AppStorage(\.chatFontSize) var chatFontSize
        
        func MakeReferenceTitle(references: [ConversationReference]) -> String {
            guard !references.isEmpty else {
                return ""
            }
            
            let count = references.count
            let title = count > 1 ? "Used \(count) references" : "Used \(count) reference"
            return title
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    isReferencesPresented.toggle()
                }, label: {
                    HStack(spacing: 4) {
                        Image(systemName: isReferencesPresented ? "chevron.down" : "chevron.right")
                            
                        Text(MakeReferenceTitle(references: references))
                            .font(.system(size: chatFontSize))
                    }
                    .background {
                        RoundedRectangle(cornerRadius: r - 4)
                            .fill(isReferencesHovered ? Color.gray.opacity(0.1) : Color.clear)
                    }
                    .foregroundStyle(.secondary)
                })
                .buttonStyle(HoverButtonStyle())
                .accessibilityValue(isReferencesPresented ? "Collapse" : "Expand")
                
                if isReferencesPresented {
                    ReferenceList(references: references, chat: chat)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray, lineWidth: 0.2)
                        )
                }
            }
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                CopilotMessageHeader()
                    .padding(.leading, 6)
                
                if !references.isEmpty {
                    WithPerceptionTracking {
                        ReferenceButton(
                            references: references,
                            chat: chat,
                            isReferencesPresented: $isReferencesPresented
                        )
                    }
                }
                
                // progress step
                if steps.count > 0 {
                    ProgressStep(steps: steps)
                }

                ThemedMarkdownText(text: text, chat: chat)

                if errorMessage != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        ThemedMarkdownText(text: errorMessage!, chat: chat)
                    }
                }

                ResponseToolBar(id: id, chat: chat, text: text)
            }
            .shadow(color: .black.opacity(0.05), radius: 6)
            .contextMenu {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                
                Button("Set as Extra System Prompt") {
                    chat.send(.setAsExtraPromptButtonTapped(id))
                }
                
                Divider()
                
                Button("Delete") {
                    chat.send(.deleteMessageButtonTapped(id))
                }
            }
        }
    }
}

struct ReferenceList: View {
    let references: [ConversationReference]
    let chat: StoreOf<Chat>

    private let maxVisibleItems: Int = 6
    @State private var itemHeight: CGFloat = 16
    
    @AppStorage(\.chatFontSize) var chatFontSize
    
    struct ReferenceView: View {
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        @AppStorage(\.chatFontSize) var chatFontSize
        @Binding var itemHeight: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<references.endIndex, id: \.self) { index in
                    WithPerceptionTracking {
                        let reference = references[index]

                        Button(action: {
                            chat.send(.referenceClicked(reference))
                        }) {
                            HStack(spacing: 8) {
                                drawFileIcon(reference.url)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text(reference.fileName)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .font(.system(size: chatFontSize))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(HoverButtonStyle())
                        .background(GeometryReader { geometry in
                            Color.clear.onAppear {
                                itemHeight = geometry.size.height
                            }
                        })
                        .help(reference.getPathRelativeToHome())
                    }
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            if references.count <= maxVisibleItems {
                ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
            } else {
                HoverScrollView {
                    ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxViewHeight)

    }
    
    private var maxViewHeight: CGFloat {
        let totalHeight = CGFloat(references.count) * itemHeight
        let maxHeight = CGFloat(maxVisibleItems) * itemHeight
        return min(totalHeight, maxHeight)
    }
}

struct BotMessage_Previews: PreviewProvider {
    static let steps: [ConversationProgressStep] = [
        .init(id: "001", title: "running step", description: "this is running step", status: .running, error: nil),
        .init(id: "002", title: "completed step", description: "this is completed step", status: .completed, error: nil),
        .init(id: "003", title: "failed step", description: "this is failed step", status: .failed, error: nil),
        .init(id: "004", title: "cancelled step", description: "this is cancelled step", status: .cancelled, error: nil)
    ]
    
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        BotMessage(
            id: "1",
            text: """
            **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
            ```swift
            func foo() {}
            ```
            """,
            references: .init(repeating: .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .class
            ), count: 2),
            followUp: ConversationFollowUp(message: "followup question", id: "id", type: "type"),
            errorMessage: "Sorry, an error occurred while generating a response.",
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }),
            steps: steps
        )
        .padding()
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct ReferenceList_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ReferenceList(references: [
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .class
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views",
                status: .included,
                kind: .struct
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .function
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .case
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .extension
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .webpage
            ),
        ], chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }))
    }
}
