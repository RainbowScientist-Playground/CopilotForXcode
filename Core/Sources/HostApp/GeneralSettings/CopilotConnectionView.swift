import ComposableArchitecture
import SwiftUI

struct CopilotConnectionView: View {
    @AppStorage("username") var username: String = ""
    @Environment(\.toast) var toast
    @StateObject var viewModel = GitHubCopilotViewModel()

    let store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
            VStack {
                connection
                    .padding(.bottom, 20)
                copilotResources
            }
        }
    }

    var accountStatus: some View {
        SettingsButtonRow(
            title: "GitHub Account Status Permissions",
            subtitle: "GitHub Connection: \(viewModel.status?.description ?? "Loading...")"
        ) {
            if viewModel.isRunningAction || viewModel.waitingForSignIn {
                ProgressView().controlSize(.small)
            }
            Button("Refresh Connection") {
                viewModel.checkStatus()
            }
            if viewModel.waitingForSignIn {
                Button("Cancel") {
                    viewModel.cancelWaiting()
                }
            } else if viewModel.status == .notSignedIn {
                Button("Login to GitHub") {
                    viewModel.signIn()
                }
                .alert(
                    viewModel.signInResponse?.userCode ?? "",
                    isPresented: $viewModel.isSignInAlertPresented,
                    presenting: viewModel.signInResponse) { _ in
                        Button("Cancel", role: .cancel, action: {})
                        Button("Copy Code and Open", action: viewModel.copyAndOpen)
                    } message: { response in
                        Text("""
                               Please enter the above code in the \
                               GitHub website to authorize your \
                               GitHub account with Copilot for Xcode.
                               
                               \(response?.verificationURL.absoluteString ?? "")
                               """)
                    }
            }
            if viewModel.status == .ok || viewModel.status == .alreadySignedIn ||
                viewModel.status == .notAuthorized
            {
                Button("Logout from GitHub") { viewModel.signOut()
                    viewModel.isSignInAlertPresented = false
                }
            }
        }
    }

    var connection: some View {
        SettingsSection(title: "Copilot Connection") {
            accountStatus
            Divider()
            SettingsLink(
                url: "https://github.com/settings/copilot",
                title: "GitHub Copilot Account Settings"
            )
        }
    }

    var copilotResources: some View {
        SettingsSection(title: "Copilot Resources") {
            SettingsLink(
                url: "https://docs.github.com/en/copilot",
                title: "View Copilot Documentation"
            )
            Divider()
            SettingsLink(
                url: "https://github.com/orgs/community/discussions/categories/copilot",
                title: "View Copilot Feedback Forum"
            )
        }
    }
}


#Preview {
    CopilotConnectionView(
        viewModel: .init(),
        store: .init(initialState: .init(), reducer: { General() })
    )
}

#Preview("Running") {
    let runningModel = GitHubCopilotViewModel()
    runningModel.isRunningAction = true
    return CopilotConnectionView(
        viewModel: runningModel,
        store: .init(initialState: .init(), reducer: { General() })
    )
}
