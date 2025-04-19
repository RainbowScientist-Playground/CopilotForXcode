import SwiftUI
import Perception
import SharedUIComponents

struct ChatNoWorkspaceView: View {
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 32) {
                    Spacer()
                    VStack (alignment: .center, spacing: 8) {
                        Image("CopilotLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFill()
                            .frame(width: 64.0, height: 64.0)
                            .foregroundColor(.secondary)
                        
                        Text("No Active Xcode Workspace")
                            .font(.largeTitle)
                            .multilineTextAlignment(.center)
                        
                        Text("To use Copilot, open Xcode with an active workspace in focus")
                            .font(.body)
                            .multilineTextAlignment(.center)
                    }
                    
                    CopilotIntroView()
                    
                    Spacer()
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .xcodeStyleFrame(cornerRadius: 10)
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct ChatNoWorkspace_Previews: PreviewProvider {
    static var previews: some View {
        ChatNoWorkspaceView()
    }
}
