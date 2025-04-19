import ComposableArchitecture
import GitHubCopilotViewModel
import SwiftUI

struct CopilotConnectionView: View {
    @AppStorage("username") var username: String = ""
    @Environment(\.toast) var toast
    @StateObject var viewModel: GitHubCopilotViewModel

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
            subtitle: "GitHub Account: \(viewModel.status?.description ?? "Loading...")"
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
                Button("Log in to GitHub") {
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
                Button("Log Out from GitHub") { viewModel.signOut()
                    viewModel.isSignInAlertPresented = false
                }
            }
        }
    }

    var connection: some View {
        SettingsSection(title: "Account Settings", showWarning: viewModel.status == .notAuthorized) {
            accountStatus
            Divider()
            if viewModel.status == .notAuthorized {
                SettingsLink(
                    url: "https://github.com/features/copilot/plans",
                    title: "Enable powerful AI features for free with the GitHub Copilot Free plan"
                )
                Divider()
            }
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
        viewModel: GitHubCopilotViewModel.shared,
        store: .init(initialState: .init(), reducer: { General() })
    )
}

#Preview("Running") {
    let runningModel =  GitHubCopilotViewModel.shared
    runningModel.isRunningAction = true
    return CopilotConnectionView(
        viewModel: GitHubCopilotViewModel.shared,
        store: .init(initialState: .init(), reducer: { General() })
    )
}
