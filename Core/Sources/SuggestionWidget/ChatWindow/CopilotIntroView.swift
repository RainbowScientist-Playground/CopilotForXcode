import SwiftUI
import Perception
import SharedUIComponents

struct CopilotIntroView: View {
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .center, spacing: 8) {
                CopilotIntroItemView(
                    imageName: "CopilotLogo",
                    title: "Inline Code Suggestion",
                    description: "Receive context-aware code suggestions and text completion in Xcode. Press Tab ⇥ to accept."
                )
                
                CopilotIntroItemView(
                    systemImage: "option",
                    title: "Full Suggestions",
                    description: "Press Option ⌥ for multi-line suggestions (first line is inline). Use Copilot Chat to refine and explain."
                )
                
                CopilotIntroItemView(
                    imageName: "ChatIcon",
                    title: "Chat",
                    description: "Get real-time coding assistance, debug issues, and generate code snippets directly within Xcode."
                )
                
                CopilotIntroItemView(
                    imageName: "GitHubMark",
                    title: "GitHub Context",
                    description: "Copilot gives smarter code suggestions with GitHub and project context. Use chat to discuss, debug, and explain your code."
                )
            }
            .padding(0)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct CopilotIntroItemView: View {
    let image: Image
    let title: String
    let description: String

    public init(imageName: String, title: String, description: String) {
        self.init(
            imageObject: Image(imageName),
            title: title,
            description: description
        )
    }

    public init(systemImage: String, title: String, description: String) {
        self.init(
            imageObject: Image(systemName: systemImage),
            title: title,
            description: description
        )
    }

    public init(imageObject: Image, title: String, description: String) {
        self.image = imageObject
        self.title = title
        self.description = description
    }
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0){
                HStack(alignment: .center, spacing: 8) {
                    image
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFill()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.primary)
                        .padding(.leading, 8)
                        
                    Text(title)
                        .font(.body)
                        .kerning(0.096)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                    
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: 360, alignment: .top)
            .background(.primary.opacity(0.1))
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .inset(by: 0.5)
                    .stroke(lineWidth: 0)
            )
        }
    }
}

struct CopilotIntroView_Previews: PreviewProvider {
    static var previews: some View {
        CopilotIntroView()
    }
}
