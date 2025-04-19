import SwiftUI

public struct HoverScrollView<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ScrollView(showsIndicators: isHovered) {
            content
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
