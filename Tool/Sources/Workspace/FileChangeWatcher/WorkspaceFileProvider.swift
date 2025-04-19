import Foundation
import ConversationServiceProvider

public protocol WorkspaceFileProvider {
    func getSubprojectURLs(in workspaceURL: URL) -> [URL]
    func getFilesInActiveWorkspace(workspaceURL: URL, workspaceRootURL: URL) -> [FileReference]
    func isXCProject(_ url: URL) -> Bool
    func isXCWorkspace(_ url: URL) -> Bool
}

public class FileChangeWatcherWorkspaceFileProvider: WorkspaceFileProvider {
    public init() {}
    
    public func getSubprojectURLs(in workspaceURL: URL) -> [URL] {
        return WorkspaceFile.getSubprojectURLs(in: workspaceURL)
    }
    
    public func getFilesInActiveWorkspace(workspaceURL: URL, workspaceRootURL: URL) -> [FileReference] {
        return WorkspaceFile.getFilesInActiveWorkspace(workspaceURL: workspaceURL, workspaceRootURL: workspaceRootURL)
    }
    
    public func isXCProject(_ url: URL) -> Bool {
        return WorkspaceFile.isXCProject(url)
    }
    
    public func isXCWorkspace(_ url: URL) -> Bool {
        return WorkspaceFile.isXCWorkspace(url)
    }
}
