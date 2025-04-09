import ComposableArchitecture
import SwiftUI

public struct Instruction: View {
    public init() {}
    
    public var body: some View {
        WithPerceptionTracking {
            VStack {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 16) {
                        Image("CopilotLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFill()
                            .frame(width: 60.0, height: 60.0)
                            .foregroundColor(.secondary)
                        
                        Text("Copilot is powered by AI, so mistakes are possible. Review output carefully before use.")
                            .font(.system(size: 14, weight: .light))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("to reference context", systemImage: "paperclip")
                            .foregroundColor(Color("DescriptionForegroundColor"))
                            .font(.system(size: 14))
                        Text("Type / to use commands")
                            .foregroundColor(Color("DescriptionForegroundColor"))
                            .font(.system(size: 14))
                    }
                }
            }.frame(maxWidth: 350)
        }
    }
}

