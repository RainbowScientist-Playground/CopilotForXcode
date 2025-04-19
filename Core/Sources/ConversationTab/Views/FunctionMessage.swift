import Foundation
import SwiftUI
import ChatService
import SharedUIComponents
import ComposableArchitecture
import ChatTab

struct FunctionMessage: View {
    let chat: StoreOf<Chat>
    let id: String
    let text: String
    @AppStorage(\.chatFontSize) var chatFontSize
    @Environment(\.openURL) private var openURL
    
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func extractDate(from text: String) -> Date? {
        guard let match = (try? NSRegularExpression(pattern: "until (.*?) for"))?
                    .firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
            let dateRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let dateString = String(text[dateRange])
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy, h:mm:ss a"
        return formatter.date(from: dateString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("CopilotLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFill()
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            .frame(width: 24, height: 24)
                    )
                    .padding(.leading, 8)
                
                Text("GitHub Copilot")
                    .font(.system(size: 13))
                    .fontWeight(.semibold)
                    .padding(4)
                    
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("You've reached your monthly chat limit for GitHub Copilot Free.")
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                
                if let date = extractDate(from: text) {
                    Text("Upgrade to Copilot Pro with a 30-day free trial or wait until \(displayFormatter.string(from: date)) for your limit to reset.")
                        .font(.system(size: 13))
                }
                
                Button("Update to Copilot Pro") {
                    if let url = URL(string: "https://github.com/github-copilot/signup/copilot_individual") {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            
//            HStack {
//                Button(action: {
//                    // Add your refresh action here
//                }) {
//                    Image(systemName: "arrow.clockwise")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 14, height: 14)
//                        .frame(width: 20, height: 20, alignment: .center)
//                        .foregroundColor(.secondary)
//                        .background(
//                            .regularMaterial,
//                            in: RoundedRectangle(cornerRadius: 4, style: .circular)
//                        )
//                        .padding(4)
//                }
//                .buttonStyle(.borderless)
//                
//                DownvoteButton { rating in
//                    chat.send(.downvote(id, rating))
//                }
//                
//                Button(action: {
//                    // Add your more options action here
//                }) {
//                    Image(systemName: "ellipsis")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 14, height: 14)
//                        .frame(width: 20, height: 20, alignment: .center)
//                        .foregroundColor(.secondary)
//                        .background(
//                            .regularMaterial,
//                            in: RoundedRectangle(cornerRadius: 4, style: .circular)
//                        )
//                        .padding(4)
//                }
//                .buttonStyle(.borderless)
//            }
        }
        .padding(.vertical, 12)
    }
}

struct FunctionMessage_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        FunctionMessage(
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }),
            id: "1",
            text: "You've reached your monthly chat limit. Upgrade to Copilot Pro (30-day free trial) or wait until 1/17/2025, 8:00:00 AM for your limit to reset."
        )
        .padding()
        .fixedSize()
    }
}
