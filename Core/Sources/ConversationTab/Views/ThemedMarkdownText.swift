import Foundation
import MarkdownUI
import SwiftUI
import ChatService
import ComposableArchitecture
import SuggestionBasic
import ChatTab

struct ThemedMarkdownText: View {
    @AppStorage(\.syncChatCodeHighlightTheme) var syncCodeHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFont) var chatCodeFont
    @Environment(\.colorScheme) var colorScheme

    let text: String
    let chat: StoreOf<Chat>

    init(text: String, chat: StoreOf<Chat>) {
        self.text = text
        self.chat = chat
    }

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.custom(
                fontSize: chatFontSize,
                codeFont: chatCodeFont.value.nsFont,
                codeBlockBackgroundColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light, let color = codeBackgroundColorLight.value {
                            return color.swiftUIColor
                        } else if let color = codeBackgroundColorDark.value {
                            return color.swiftUIColor
                        }
                    }

                    return Color(nsColor: .textBackgroundColor).opacity(0.7)
                }(),
                codeBlockLabelColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light,
                           let color = codeForegroundColorLight.value
                        {
                            return color.swiftUIColor.opacity(0.5)
                        } else if let color = codeForegroundColorDark.value {
                            return color.swiftUIColor.opacity(0.5)
                        }
                    }
                    return Color.secondary.opacity(0.7)
                }(),
                chat: chat
            ))
    }
}

// MARK: - Theme

extension MarkdownUI.Theme {
    static func custom(
        fontSize: Double,
        codeFont: NSFont,
        codeBlockBackgroundColor: Color,
        codeBlockLabelColor: Color,
        chat: StoreOf<Chat>
    ) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(.primary)
            BackgroundColor(Color.clear)
            FontSize(fontSize)
        }
        .codeBlock { configuration in
            MarkdownCodeBlockView(
                codeBlockConfiguration: configuration,
                codeFont: codeFont,
                codeBlockBackgroundColor: codeBlockBackgroundColor,
                codeBlockLabelColor: codeBlockLabelColor,
                chat: chat
            )
        }
    }
}

struct MarkdownCodeBlockView: View {
    let codeBlockConfiguration: CodeBlockConfiguration
    let codeFont: NSFont
    let codeBlockBackgroundColor: Color
    let codeBlockLabelColor: Color
    let chat: StoreOf<Chat>
    
    func insertCode() {
        chat.send(.insertCode(codeBlockConfiguration.content))
    }
    
    var body: some View {
        let wrapCode = UserDefaults.shared.value(for: \.wrapCodeInChatCodeBlock)

        if wrapCode {
            AsyncCodeBlockView(
                fenceInfo: codeBlockConfiguration.language,
                content: codeBlockConfiguration.content,
                font: codeFont
            )
            .codeBlockLabelStyle()
            .codeBlockStyle(
                codeBlockConfiguration,
                backgroundColor: codeBlockBackgroundColor,
                labelColor: codeBlockLabelColor,
                insertAction: insertCode
            )
        } else {
            ScrollView(.horizontal) {
                AsyncCodeBlockView(
                    fenceInfo: codeBlockConfiguration.language,
                    content: codeBlockConfiguration.content,
                    font: codeFont
                )
                .codeBlockLabelStyle()
            }
            .workaroundForVerticalScrollingBugInMacOS()
            .codeBlockStyle(
                codeBlockConfiguration,
                backgroundColor: codeBlockBackgroundColor,
                labelColor: codeBlockLabelColor,
                insertAction: insertCode
            )
        }
    }
}

struct ThemedMarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ThemedMarkdownText(
            text:"""
    ```swift
    let sumClosure: (Int, Int) -> Int = { (a: Int, b: Int) in
        return a + b
    }
    ```
    """,
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }))
    }
}

