// HensonDayApp.swift

import SwiftUI

@main
struct HensonDayApp: App {
    private let environment: AppEnvironment
    @StateObject private var modelController = ModelController()
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var cameraPermission = CameraPermissionManager()
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var contentService: ContentService

    init() {
        let environment = AppEnvironment.current
        self.environment = environment
        _contentService = StateObject(wrappedValue: ContentService(environment: environment))
    }

    private func applyAvailableRemoteContent() {
        if environment.featureFlags.enableRemoteCampusConfig,
           let remoteConfig = contentService.remoteCampusConfig {
            CampusConfigProvider.applyRemoteConfig(remoteConfig)
        }

        if contentService.hasRemoteOverlayContent {
            modelController.applyRemoteContent(from: contentService)
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchGateView()
                .environmentObject(modelController)
                .environmentObject(tabRouter)
                .environmentObject(cameraPermission)
                .environmentObject(locationManager)
                .environmentObject(contentService)
                .task {
                    await contentService.loadFromBundle()

                    if contentService.restoreCachedRemoteContentIfAvailable() {
                        applyAvailableRemoteContent()
                    }

                    if environment.usesRemoteContent {
                        await contentService.refreshFromRemote()
                        switch contentService.syncState {
                        case .synced, .stale:
                            applyAvailableRemoteContent()
                        default:
                            break
                        }
                    }
                }
                .preferredColorScheme(.light)
        }
    }
}
