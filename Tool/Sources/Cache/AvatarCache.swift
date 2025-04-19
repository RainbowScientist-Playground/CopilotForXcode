import Foundation
import SwiftUI
import AppKit

public final class AvatarCache {
    public static let shared = AvatarCache()
    private let cache = NSCache<NSString, NSData>()
    
    private init () {}
    
    public func set(forUser username: String) async  -> Void {
        guard let data = await fetchAvatarData(forUser: username) else { return }
        cache.setObject(data as NSData, forKey: username as NSString)
    }
    
    public func get(forUser username: String) -> Data? {
        return cache.object(forKey: username as NSString) as Data?
    }
    
    public func remove(forUser username: String) {
        cache.removeObject(forKey: username as NSString)
    }
}

extension AvatarCache {
    // Directly get the avatar from URL like https://avatars.githubusercontent.com/<username>
    // TODO: when the `agent` feature added, the avatarUrl could be obtained from the response of GitHub LSP
    func fetchAvatarData(forUser username: String) async -> Data? {
        let avatarUrl = "https://avatars.githubusercontent.com/\(username)"
        guard let avatarUrl = URL(string: avatarUrl) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: avatarUrl)
            return data
        } catch {
            return nil
        }
    }
    
    public func getAvatarImage(forUser username: String) -> Image? {
        guard let data = get(forUser: username),
              let nsImage = NSImage(data: data)
        else {
            return nil
        }
        
        return Image(nsImage: nsImage)
    }
}
