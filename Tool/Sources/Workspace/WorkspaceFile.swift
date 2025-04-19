import Foundation
import Logger
import ConversationServiceProvider

public let supportedFileExtensions: Set<String> = ["swift", "m", "mm", "h", "cpp", "c", "js", "py", "rb", "java", "applescript", "scpt", "plist", "entitlements", "md", "json", "xml", "txt", "yaml", "yml"]
public let skipPatterns: [String] = [
    ".git",
    ".svn",
    ".hg",
    "CVS",
    ".DS_Store",
    "Thumbs.db",
    "node_modules",
    "bower_components"
]


public struct WorkspaceFile {
    
    static func isXCWorkspace(_ url: URL) -> Bool {
        return url.pathExtension == "xcworkspace" && FileManager.default.fileExists(atPath: url.appendingPathComponent("contents.xcworkspacedata").path)
    }
    
    static func isXCProject(_ url: URL) -> Bool {
        return url.pathExtension == "xcodeproj" && FileManager.default.fileExists(atPath: url.appendingPathComponent("project.pbxproj").path)
    }
    
    static func getWorkspaceByProject(_ url: URL) -> URL? {
        guard isXCProject(url) else { return nil }
        let workspaceURL = url.appendingPathComponent("project.xcworkspace")
        
        return isXCWorkspace(workspaceURL) ? workspaceURL : nil
    }
    
    static func getSubprojectURLs(workspaceURL: URL, data: Data) -> [URL] {
        var subprojectURLs: [URL] = []
        do {
            let xml = try XMLDocument(data: data)
            let fileRefs = try xml.nodes(forXPath: "//FileRef")
            for fileRef in fileRefs {
                if let fileRefElement = fileRef as? XMLElement,
                   let location = fileRefElement.attribute(forName: "location")?.stringValue {
                    var path = ""
                    if location.starts(with: "group:") {
                        path = location.replacingOccurrences(of: "group:", with: "")
                    } else if location.starts(with: "container:") {
                        path = location.replacingOccurrences(of: "container:", with: "")
                    } else if location.starts(with: "self:") {
                        // Handle "self:" referece - refers to the containing project directory
                        var workspaceURLCopy = workspaceURL
                        workspaceURLCopy.deleteLastPathComponent()
                        path = workspaceURLCopy.path
                        
                    } else {
                        // Skip absolute paths such as absolute:/path/to/project
                        continue
                    }

                    if path.hasSuffix(".xcodeproj") {
                        path = (path as NSString).deletingLastPathComponent
                    }
                    let subprojectURL = path.isEmpty ? workspaceURL.deletingLastPathComponent() : workspaceURL.deletingLastPathComponent().appendingPathComponent(path)
                    if !subprojectURLs.contains(subprojectURL) {
                        subprojectURLs.append(subprojectURL)
                    }
                }
            }
        } catch {
            Logger.client.error("Failed to parse workspace file: \(error)")
        }

        return subprojectURLs
    }
    
    static func getSubprojectURLs(in workspaceURL: URL) -> [URL] {
        let workspaceFile = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
        guard let data = try? Data(contentsOf: workspaceFile) else {
            Logger.client.error("Failed to read workspace file at \(workspaceFile.path)")
            return []
        }

        return getSubprojectURLs(workspaceURL: workspaceURL, data: data)
    }
    
    static func matchesPatterns(_ url: URL, patterns: [String]) -> Bool {
        let fileName = url.lastPathComponent
        for pattern in patterns {
            if fnmatch(pattern, fileName, 0) == 0 {
                return true
            }
        }
        return false
    }
    
    public static func getFilesInActiveWorkspace(
        workspaceURL: URL,
        workspaceRootURL: URL,
        shouldExcludeFile: ((URL) -> Bool)? = nil
    ) -> [FileReference] {
        var files: [FileReference] = []
        do {
            let fileManager = FileManager.default
            var subprojects: [URL] = []
            if isXCWorkspace(workspaceURL) {
                subprojects = getSubprojectURLs(in: workspaceURL)
            } else {
                subprojects.append(workspaceRootURL)
            }
            for subproject in subprojects {
                guard FileManager.default.fileExists(atPath: subproject.path) else {
                    continue
                }

                let enumerator = fileManager.enumerator(
                    at: subproject,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                while let fileURL = enumerator?.nextObject() as? URL {
                    // Skip items matching the specified pattern
                    if matchesPatterns(fileURL, patterns: skipPatterns) || isXCWorkspace(fileURL) ||
                        isXCProject(fileURL) {
                        enumerator?.skipDescendants()
                        continue
                    }

                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                    // Handle directories if needed
                    if resourceValues.isDirectory == true {
                        continue
                    }

                    guard resourceValues.isRegularFile == true else { continue }
                    if supportedFileExtensions.contains(fileURL.pathExtension.lowercased()) == false {
                        continue
                    }
                    
                    // Apply the custom file exclusion check if provided
                    if let shouldExcludeFile = shouldExcludeFile,
                       shouldExcludeFile(fileURL) { continue }

                    let relativePath = fileURL.path.replacingOccurrences(of: workspaceRootURL.path, with: "")
                    let fileName = fileURL.lastPathComponent

                    let file = FileReference(url: fileURL, relativePath: relativePath, fileName: fileName)
                    files.append(file)
                }
            }
        } catch {
            Logger.client.error("Failed to get files in workspace: \(error)")
        }

        return files
    }
    
    /*
     used for `project-context` skill. Get filed for watching for syncing to CLS
     */
    public static func getWatchedFiles(
        workspaceURL: URL,
        projectURL: URL,
        excludeGitIgnoredFiles: Bool,
        excludeIDEIgnoredFiles: Bool
    ) -> [String] {
        // Directly return for invalid workspace
        guard workspaceURL.path != "/" else { return [] }
        
        // TODO: implement
        let shouldExcludeFile: ((URL) -> Bool)? = nil
        
        let files = getFilesInActiveWorkspace(
            workspaceURL: workspaceURL,
            workspaceRootURL: projectURL,
            shouldExcludeFile: shouldExcludeFile
        )
        
        return files.map { $0.url.absoluteString }
    }
}
