import Client
import ComposableArchitecture
import Foundation
import LaunchAgentManager
import Status
import SwiftUI
import XPCShared
import Logger

@Reducer
struct General {
    @ObservableState
    struct State: Equatable {
        var xpcServiceVersion: String?
        var isAccessibilityPermissionGranted: ObservedAXStatus = .unknown
        var isExtensionPermissionGranted: ExtensionPermissionStatus = .unknown
        var isReloading = false
    }

    enum Action: Equatable {
        case appear
        case setupLaunchAgentIfNeeded
        case openExtensionManager
        case reloadStatus
        case finishReloading(
            xpcServiceVersion: String,
            axStatus: ObservedAXStatus,
            extensionStatus: ExtensionPermissionStatus
        )
        case failedReloading
        case retryReloading
    }

    @Dependency(\.toast) var toast
    
    struct ReloadStatusCancellableId: Hashable {}
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.setupLaunchAgentIfNeeded)
                    for await _ in DistributedNotificationCenter.default().notifications(named: .serviceStatusDidChange) {
                        await send(.reloadStatus)
                    }
                }

            case .setupLaunchAgentIfNeeded:
                return .run { send in
                    #if DEBUG
                    // do not auto install on debug build
                    await send(.reloadStatus)
                    #else
                    Task {
                        do {
                            try await LaunchAgentManager()
                                .setupLaunchAgentForTheFirstTimeIfNeeded()
                        } catch {
                            Logger.ui.error("Failed to setup launch agent. \(error.localizedDescription)")
                            toast(error.localizedDescription, .error)
                        }
                        await send(.reloadStatus)
                    }
                    #endif
                }

            case .openExtensionManager:
                return .run { send in
                    let service = try getService()
                    do {
                        _ = try await service
                            .send(requestBody: ExtensionServiceRequests.OpenExtensionManager())
                    } catch {
                        Logger.ui.error("Failed to open extension manager. \(error.localizedDescription)")
                        toast(error.localizedDescription, .error)
                        await send(.failedReloading)
                    }
                }

            case .reloadStatus:
                guard !state.isReloading else { return .none }
                state.isReloading = true
                return .run { send in
                    let service = try getService()
                    do {
                        let isCommunicationReady = try await service.launchIfNeeded()
                        if isCommunicationReady {
                            let xpcServiceVersion = try await service.getXPCServiceVersion().version
                            let isAccessibilityPermissionGranted = try await service
                                .getXPCServiceAccessibilityPermission()
                            let isExtensionPermissionGranted = try await service.getXPCServiceExtensionPermission()
                            await send(.finishReloading(
                                xpcServiceVersion: xpcServiceVersion,
                                axStatus: isAccessibilityPermissionGranted,
                                extensionStatus: isExtensionPermissionGranted
                            ))
                        } else {
                            toast("Launching service app.", .info)
                            try await Task.sleep(nanoseconds: 5_000_000_000)
                            await send(.retryReloading)
                        }
                    } catch let error as XPCCommunicationBridgeError {
                        Logger.ui.error("Failed to reach communication bridge. \(error.localizedDescription)")
                        toast(
                            "Failed to reach communication bridge. \(error.localizedDescription)",
                            .error
                        )
                        await send(.failedReloading)
                    } catch {
                        Logger.ui.error("Failed to reload status. \(error.localizedDescription)")
                        toast(error.localizedDescription, .error)
                        await send(.failedReloading)
                    }
                }.cancellable(id: ReloadStatusCancellableId(), cancelInFlight: true)

            case let .finishReloading(version, axStatus, extensionStatus):
                state.xpcServiceVersion = version
                state.isAccessibilityPermissionGranted = axStatus
                state.isExtensionPermissionGranted = extensionStatus
                state.isReloading = false
                return .none

            case .failedReloading:
                state.isReloading = false
                return .none

            case .retryReloading:
                state.isReloading = false
                return .run { send in
                    await send(.reloadStatus)
                }
            }
        }
    }
}

