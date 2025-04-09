import ComposableArchitecture
import ChatService
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI
import Status
import Cache
import ChatTab

struct UserMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var statusObserver = StatusObserver.shared
    
    struct AvatarView: View {
        @ObservedObject private var avatarViewModel = AvatarViewModel.shared
        
        var body: some View {
            if let avatarImage = avatarViewModel.avatarImage {
                avatarImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    AvatarView()

                    Text(statusObserver.authStatus.username ?? "")
                        .chatMessageHeaderTextStyle()
                        .padding(2)
                    
                    Spacer()
                }
                
                ThemedMarkdownText(text: text, chat: chat)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 6)
    }
}

struct UserMessage_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        UserMessage(
            id: "A",
            text: #"""
            Please buy me a coffee!
            | Coffee | Milk |
            |--------|------|
            | Espresso | No |
            | Latte | Yes |
            ```swift
            func foo() {}
            ```
            ```objectivec
            - (void)bar {}
            ```
            """#,
            chat: .init(
                initialState: .init(history: [] as [DisplayedChatMessage], isReceivingMessage: false),
                reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }
            )
        )
        .padding()
        .fixedSize(horizontal: true, vertical: true)
        .background(Color.yellow)
        
    }
}
