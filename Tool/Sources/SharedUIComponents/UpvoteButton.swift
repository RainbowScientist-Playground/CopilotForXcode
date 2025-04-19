import AppKit
import SwiftUI
import ConversationServiceProvider

public struct UpvoteButton: View {
    public var upvote: (ConversationRating) -> Void
    @State var isSelected = false
    
    public init(upvote: @escaping (ConversationRating) -> Void) {
        self.upvote = upvote
    }
    
    public var body: some View {
        Button(action: {
            isSelected = !isSelected
            isSelected ? upvote(.helpful) : upvote(.unrated)
        }) {
            Image(systemName: isSelected ? "hand.thumbsup.fill" : "hand.thumbsup")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
//                .frame(width: 20, height: 20, alignment: .center)
                .foregroundColor(.secondary)
//                .background(
//                    .regularMaterial,
//                    in: RoundedRectangle(cornerRadius: 4, style: .circular)
//                )
                .padding(4)
                .help("Helpful")
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
    }
}
