import Combine
import SwiftUI

public struct FeatureFlags: Hashable, Codable {
    public var rt: Bool
    public var sn: Bool
    public var chat: Bool
    public var xc: Bool?
}

public protocol FeatureFlagNotifier {
    var featureFlags: FeatureFlags { get }
    var featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never> { get }
    func handleFeatureFlagNotification(_ featureFlags: FeatureFlags)
}

public class FeatureFlagNotifierImpl: FeatureFlagNotifier {
    public var featureFlags: FeatureFlags
    public static let shared = FeatureFlagNotifierImpl()
    public var featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never>
    
    init(featureFlags: FeatureFlags = FeatureFlags(rt: false, sn: false, chat: true),
         featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never> = PassthroughSubject<FeatureFlags, Never>()) {
        self.featureFlags = featureFlags
        self.featureFlagsDidChange = featureFlagsDidChange
    }

    public func handleFeatureFlagNotification(_ featureFlags: FeatureFlags) {
        self.featureFlags = featureFlags
        self.featureFlags.chat = featureFlags.chat == true && featureFlags.xc == true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.featureFlagsDidChange.send(self.featureFlags)
        }
    }
}
