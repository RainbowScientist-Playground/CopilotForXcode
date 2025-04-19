import Foundation
import GitHubCopilotService
import ComposableArchitecture
import Status
import SwiftUI
import Cache

public struct SignInResponse {
    public let status: SignInInitiateStatus
    public let userCode: String
    public let verificationURL: URL
}

@MainActor
public class GitHubCopilotViewModel: ObservableObject {
    // Add static shared instance
    public static let shared = GitHubCopilotViewModel()
    
    @Dependency(\.toast) var toast
    @Dependency(\.openURL) var openURL
    
    @AppStorage("username") var username: String = ""
    
    @Published public var isRunningAction: Bool = false
    @Published public var status: GitHubCopilotAccountStatus?
    @Published public var version: String?
    @Published public var userCode: String?
    @Published public var isSignInAlertPresented = false
    @Published public var signInResponse: SignInResponse?
    @Published public var waitingForSignIn = false
    
    static var copilotAuthService: GitHubCopilotService?
    
    // Make init private to enforce singleton pattern
    private init() {}
    
    public func getGitHubCopilotAuthService() throws -> GitHubCopilotService {
        if let service = Self.copilotAuthService { return service }
        let service = try GitHubCopilotService()
        Self.copilotAuthService = service
        return service
    }
    
    public func preSignIn() async throws -> SignInResponse? {
        let service = try getGitHubCopilotAuthService()
        let result = try await service.signInInitiate()
        
        if result.status == .alreadySignedIn {
            guard let user = result.user else {
                toast("Missing user info.", .error)
                throw NSError(domain: "Missing user info.", code: 0, userInfo: nil)
            }
            await Status.shared.updateAuthStatus(.loggedIn, username: user)
            self.username = user
            broadcastStatusChange()
            return nil
        }
        
        guard let uri = result.verificationUri,
              let userCode = result.userCode,
              let url = URL(string: uri) else {
            toast("Verification URI is incorrect.", .error)
            throw NSError(domain: "Verification URI is incorrect.", code: 0, userInfo: nil)
        }
        return SignInResponse(
            status: SignInInitiateStatus.promptUserDeviceFlow,
            userCode: userCode,
            verificationURL: url
        )
    }
    
    public func signIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                guard let result = try await preSignIn() else { return }
                self.signInResponse = result
                self.isSignInAlertPresented = true
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
    
    public func checkStatus() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.checkStatus()
                version = try await service.version()
                isRunningAction = false
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
    
    public func signOut() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.signOut()
                await Status.shared.updateAuthStatus(.notLoggedIn)
                await Status.shared.updateCLSStatus(.unknown, busy: false, message: "")
                username = ""
                broadcastStatusChange()
            } catch {
                toast(error.localizedDescription, .error)
            }

            // Sign out all other CLS instances
            do {
                try await GitHubCopilotService.signOutAll()
            } catch {
                // ignore
            }
        }
    }
    
    public func cancelWaiting() {
        waitingForSignIn = false
    }
    
    public func copyAndOpen() {
        waitingForSignIn = true
        guard let signInResponse else {
            toast("Missing sign in details.", .error)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(signInResponse.userCode, forType: NSPasteboard.PasteboardType.string)
        toast("Sign-in code \(signInResponse.userCode) copied", .info)
        Task {
            await openURL(signInResponse.verificationURL)
            waitForSignIn()
        }
    }
    
    public func waitForSignIn() {
        Task {
            do {
                guard waitingForSignIn else { return }
                guard let signInResponse else {
                    waitingForSignIn = false
                    return
                }
                let service = try getGitHubCopilotAuthService()
                let (username, status) = try await service.signInConfirm(userCode: signInResponse.userCode)
                waitingForSignIn = false
                self.username = username
                self.status = status
                await Status.shared.updateAuthStatus(.loggedIn, username: username)
                broadcastStatusChange()
                let models = try? await service.models()
                if let models = models, !models.isEmpty {
                    CopilotModelManager.updateLLMs(models)
                }
            } catch let error as GitHubCopilotError {
                if case .languageServerError(.timeout) = error {
                    // TODO figure out how to extend the default timeout on a Chime LSP request
                    // Until then, reissue request
                    waitForSignIn()
                    return
                }
                throw error
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }

    public func broadcastStatusChange() {
        DistributedNotificationCenter.default().post(
            name: .authStatusDidChange,
            object: nil
        )
    }
}
