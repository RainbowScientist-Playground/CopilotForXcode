import SwiftUI

public struct InsertButton: View {
    public var insert: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var icon: Image {
        return Image("CodeBlockInsertIcon")
    }
    
    public init(insert: @escaping () -> Void) {
        self.insert = insert
    }
    
    public var body: some View {
        Button(action: {
            insert()
        }) {
            self.icon
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
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .help("Insert at Cursor")
    }
}
