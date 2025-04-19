import Foundation
import System
import Logger
import CoreServices
import LanguageServerProtocol
import XcodeInspector

public typealias PublisherType = (([FileEvent]) -> Void)

protocol FileChangeWatcher {
    func onFileCreated(file: URL)
    func onFileChanged(file: URL)
    func onFileDeleted(file: URL)
    
    func addPaths(_ paths: [URL])
    func removePaths(_ paths: [URL])
}

public final class BatchingFileChangeWatcher: FileChangeWatcher {
    private var watchedPaths: [URL]
    private let changePublisher: PublisherType
    private let publishInterval: TimeInterval
    
    private var pendingEvents: [FileEvent] = []
    private var timer: Timer?
    private let eventQueue: DispatchQueue
    private let fsEventQueue: DispatchQueue
    private var eventStream: FSEventStreamRef?
    private(set) public var isWatching = false
    
    // Dependencies injected for testing
    private let fsEventProvider: FSEventProvider
    
    public var paths: [URL] { watchedPaths }
    
    /// TODO: set a proper value for stdio
    public static let maxEventPublishSize = 100
    
    init(
        watchedPaths: [URL],
        changePublisher: @escaping PublisherType,
        publishInterval: TimeInterval = 3.0,
        fsEventProvider: FSEventProvider = FileChangeWatcherFSEventProvider()
    ) {
        self.watchedPaths = watchedPaths
        self.changePublisher = changePublisher
        self.publishInterval = publishInterval
        self.fsEventProvider = fsEventProvider
        self.eventQueue = DispatchQueue(label: "com.github.copilot.filechangewatcher")
        self.fsEventQueue = DispatchQueue(label: "com.github.copilot.filechangewatcherfseventstream", qos: .utility)
        
        self.start()
    }
    
    private func updateWatchedPaths(_ paths: [URL]) {
        guard isWatching, paths != watchedPaths else { return }
        stopWatching()
        watchedPaths = paths
        _ = startWatching()
    }
    
    public func addPaths(_ paths: [URL]) {
        let newPaths = paths.filter { !watchedPaths.contains($0) }
        if !newPaths.isEmpty {
            let updatedPaths = watchedPaths + newPaths
            updateWatchedPaths(updatedPaths)
        }
    }
    
    public func removePaths(_ paths: [URL]) {
        let updatedPaths = watchedPaths.filter { !paths.contains($0) }
        if updatedPaths.count != watchedPaths.count {
            updateWatchedPaths(updatedPaths)
        }
    }
    
    internal func start() {
        guard !isWatching else { return }
        
        guard self.startWatching() else {
            Logger.client.info("Failed to start watching for: \(watchedPaths)")
            return
        }
        self.startPublishTimer()
        isWatching = true
    }
    
    deinit {
        stopWatching()
        self.timer?.invalidate()
    }
    
    internal func startPublishTimer() {
        guard self.timer == nil else { return }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.publishInterval, repeats: true) { [weak self] _ in
                self?.publishChanges()
            }
        }
    }
    
    internal func addEvent(file: URL, type: FileChangeType) {
        eventQueue.async {
            self.pendingEvents.append(FileEvent(uri: file.absoluteString, type: type))
        }
    }
    
    public func onFileCreated(file: URL) {
        addEvent(file: file, type: .created)
    }
    
    public func onFileChanged(file: URL) {
        addEvent(file: file, type: .changed)
    }
    
    public func onFileDeleted(file: URL) {
        addEvent(file: file, type: .deleted)
    }
    
    private func publishChanges() {
        eventQueue.async {
            guard !self.pendingEvents.isEmpty else { return }
            
            var compressedEvent: [String: FileEvent] = [:]
            for event in self.pendingEvents {
                let existingEvent = compressedEvent[event.uri]
                
                guard existingEvent != nil else {
                    compressedEvent[event.uri] = event
                    continue
                }
                
                if event.type == .deleted { /// file deleted. Cover created and changed event
                    compressedEvent[event.uri] = event
                } else if event.type == .created { /// file created. Cover deleted and changed event
                    compressedEvent[event.uri] = event
                } else if event.type == .changed {
                    if existingEvent?.type != .created { /// file changed. Won't cover created event
                        compressedEvent[event.uri] = event
                    }
                }
            }
            
            let compressedEventArray: [FileEvent] = Array(compressedEvent.values)
            
            let changes = Array(compressedEventArray.prefix(BatchingFileChangeWatcher.maxEventPublishSize))
            if compressedEventArray.count > BatchingFileChangeWatcher.maxEventPublishSize {
                self.pendingEvents = Array(compressedEventArray[BatchingFileChangeWatcher.maxEventPublishSize..<compressedEventArray.count])
            } else {
                self.pendingEvents.removeAll()
            }
            
            if !changes.isEmpty {
                DispatchQueue.main.async {
                    self.changePublisher(changes)
                }
            }
        }
    }
    
    /// Starts watching  for file changes in the project
    private func startWatching() -> Bool {
        var isEventStreamStarted = false
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let paths = watchedPaths.map { $0.path } as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagWatchRoot
        )
        
        eventStream = fsEventProvider.createEventStream(
            paths: paths,
            latency: 1, // 1 second latency,
            flags: flags,
            callback: { _, clientCallbackInfo, numEvents, eventPaths, eventFlags, _ in
                guard let clientCallbackInfo = clientCallbackInfo else { return }
                let watcher = Unmanaged<BatchingFileChangeWatcher>.fromOpaque(clientCallbackInfo).takeUnretainedValue()
                watcher.processEvent(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
            },
            context: &context
        )
        
        if let eventStream = eventStream {
            fsEventProvider.setDispatchQueue(eventStream, queue: fsEventQueue)
            fsEventProvider.startStream(eventStream)
            isEventStreamStarted = true
        }
        
        return isEventStreamStarted
    }
    
    /// Stops watching for file changes
    internal func stopWatching() {
        guard isWatching, let eventStream = eventStream else { return }
        
        fsEventProvider.stopStream(eventStream)
        fsEventProvider.invalidateStream(eventStream)
        fsEventProvider.releaseStream(eventStream)
        self.eventStream = nil
        isWatching = false
        
        Logger.client.info("Stoped watching for file changes in \(watchedPaths)")
    }
    
    public func processEvent(numEvents: CFIndex, eventPaths: UnsafeRawPointer, eventFlags: UnsafePointer<UInt32>) {
        let pathsPtr = eventPaths.bindMemory(to: UnsafeMutableRawPointer.self, capacity: numEvents)
        
        for i in 0..<numEvents {
            let pathPtr = pathsPtr[Int(i)]
            let path = String(cString: pathPtr.assumingMemoryBound(to: CChar.self))
            let flags = eventFlags[Int(i)]
            
            let url = URL(fileURLWithPath: path)
            
            guard !shouldIgnoreURL(url: url) else { continue }
            
            let fileExists = FileManager.default.fileExists(atPath: path)
            
            /// FileSystem events can have multiple flags set simultaneously,
            
            if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                if fileExists { onFileCreated(file: url) }
            }
            
            if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
                onFileDeleted(file: url)
            }
            
            /// The fiesystem report "Renamed" event when file content changed.
            if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                if fileExists { onFileChanged(file: url) }
                else { onFileDeleted(file: url) }
            }
            
            if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
                if fileExists { onFileChanged(file: url) }
                else { onFileDeleted(file: url)}
            }
        }
    }
}

extension BatchingFileChangeWatcher {
    internal func shouldIgnoreURL(url: URL) -> Bool {
        if let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey]),
           resourceValues.isDirectory == true { return true }
        
        if supportedFileExtensions.contains(url.pathExtension.lowercased()) == false { return true }
        
        if WorkspaceFile.isXCProject(url) || WorkspaceFile.isXCWorkspace(url) { return true }
        
        if WorkspaceFile.matchesPatterns(url, patterns: skipPatterns) { return true }
        
        // TODO: check if url is ignored by git / ide
        
        return false
    }
}

public class FileChangeWatcherService {
    internal var watcher: BatchingFileChangeWatcher?
    /// for watching projects added or removed
    private var timer: Timer?
    private var projectWatchingInterval: TimeInterval = 3.0
    
    private(set) public var workspaceURL: URL
    private(set) public var publisher: PublisherType
    
    // Dependencies injected for testing
    internal let workspaceFileProvider: WorkspaceFileProvider
    internal let watcherFactory: ([URL], @escaping PublisherType) -> BatchingFileChangeWatcher
        
    public init(
        _ workspaceURL: URL,
        publisher: @escaping PublisherType,
        publishInterval: TimeInterval = 3.0,
        projectWatchingInterval: TimeInterval = 3.0,
        workspaceFileProvider: WorkspaceFileProvider = FileChangeWatcherWorkspaceFileProvider(),
        watcherFactory: (([URL], @escaping PublisherType) -> BatchingFileChangeWatcher)? = nil
    ) {
        self.workspaceURL = workspaceURL
        self.publisher = publisher
        self.workspaceFileProvider = workspaceFileProvider
        self.watcherFactory = watcherFactory ?? { projectURLs, publisher in
            BatchingFileChangeWatcher(watchedPaths: projectURLs, changePublisher: publisher, publishInterval: publishInterval)
        }
    }
    
    deinit {
        self.watcher = nil
        self.timer?.invalidate()
    }
    
    internal func startWatchingProject() {
        guard timer == nil else { return }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            self.timer = Timer.scheduledTimer(withTimeInterval: self.projectWatchingInterval, repeats: true) { [weak self] _ in
                guard let self, let watcher = self.watcher else { return }
                
                let watchingProjects = Set(watcher.paths)
                let projects = Set(self.workspaceFileProvider.getSubprojectURLs(in: self.workspaceURL))
                
                /// find added projects
                let addedProjects = projects.subtracting(watchingProjects)
                self.onProjectAdded(Array(addedProjects))
                
                /// find removed projects
                let removedProjects = watchingProjects.subtracting(projects)
                self.onProjectRemoved(Array(removedProjects))
            }
        }
    }
    
    public func startWatching() {
        guard workspaceURL.path != "/" else { return }
        
        guard watcher == nil else { return }
        
        let projects = workspaceFileProvider.getSubprojectURLs(in: workspaceURL)
        
        watcher = watcherFactory(projects, publisher)
        Logger.client.info("Started watching for file changes in \(projects)")
        
        startWatchingProject()
    }
    
    internal func onProjectAdded(_ projectURLs: [URL]) {
        guard let watcher = watcher, projectURLs.count > 0 else { return }
        
        watcher.addPaths(projectURLs)

        Logger.client.info("Started watching for file changes in \(projectURLs)")
        
        /// sync all the files as created in the project when added
        for projectURL in projectURLs {
            let files = workspaceFileProvider.getFilesInActiveWorkspace(
                workspaceURL: projectURL,
                workspaceRootURL: projectURL
            )
            publisher(files.map { .init(uri: $0.url.absoluteString, type: .created) })
        }
    }
    
    internal func onProjectRemoved(_ projectURLs: [URL]) {
        guard let watcher = watcher, projectURLs.count > 0 else { return }
        
        watcher.removePaths(projectURLs)
        
        Logger.client.info("Stopped watching for file changes in \(projectURLs)")
        
        /// sync all the files as deleted in the project when removed
        for projectURL in projectURLs {
            let files = workspaceFileProvider.getFilesInActiveWorkspace(workspaceURL: projectURL, workspaceRootURL: projectURL)
            publisher(files.map { .init(uri: $0.url.absoluteString, type: .deleted) })
        }
    }
}

@globalActor
public enum PoolActor: GlobalActor {
    public actor Actor {}
    public static let shared = Actor()
}

public class FileChangeWatcherServicePool {
    
    public static let shared = FileChangeWatcherServicePool()
    private var servicePool: [URL: FileChangeWatcherService] = [:]
    
    private init() {}
    
    @PoolActor
    public func watch(for workspaceURL: URL, publisher: @escaping PublisherType) {
        guard workspaceURL.path != "/" else { return }
        
        var validWorkspaceURL: URL? = nil
        if WorkspaceFile.isXCWorkspace(workspaceURL) {
            validWorkspaceURL = workspaceURL
        } else if WorkspaceFile.isXCProject(workspaceURL) {
            validWorkspaceURL = WorkspaceFile.getWorkspaceByProject(workspaceURL)
        }
        
        guard let validWorkspaceURL else { return }
        
        guard servicePool[workspaceURL] == nil else { return }
        
        let watcherService = FileChangeWatcherService(validWorkspaceURL, publisher: publisher)
        watcherService.startWatching()
        
        servicePool[workspaceURL] = watcherService
    }
}
