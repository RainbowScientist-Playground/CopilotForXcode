import SwiftUI

@MainActor
public class AvatarViewModel: ObservableObject {
    @Published private(set) public var avatarImage: Image?
    public static let shared = AvatarViewModel()
        
    public init() { }
    
    public func loadAvatar(forUser userName: String?) {
        guard let userName = userName, !userName.isEmpty
        else {
            avatarImage = nil
            return
        }
        
        // Fetch if not in cache
        Task {
            await AvatarCache.shared.set(forUser: userName)
            self.avatarImage = AvatarCache.shared.getAvatarImage(forUser: userName)
        }
    }
}
