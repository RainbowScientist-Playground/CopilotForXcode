import SwiftUI

public struct CopilotMessageHeader: View {
    public init() {}
    
    public var body: some View {
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
            Text("GitHub Copilot")
                .font(.system(size: 13))
                .fontWeight(.semibold)
                .padding(4)
                
            Spacer()
        }
    }
}
