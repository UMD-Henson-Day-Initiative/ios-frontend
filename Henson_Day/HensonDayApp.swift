// HensonDayApp.swift

import SwiftUI

@main
struct HensonDayApp: App {
    private let environment: AppEnvironment
    @StateObject private var modelController = ModelController()
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var cameraPermission = CameraPermissionManager()
    @StateObject private var worldAnchorManager = WorldAnchorManager()
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var contentService: ContentService

    init() {
        let environment = AppEnvironment.current
        self.environment = environment
        _contentService = StateObject(wrappedValue: ContentService(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            LaunchGateView()
                .environmentObject(modelController)
                .environmentObject(tabRouter)
                .environmentObject(cameraPermission)
                .environmentObject(worldAnchorManager)
                .environmentObject(locationManager)
                .environmentObject(contentService)
                .task {
                    await contentService.loadContent()
                    // Apply remote campus config when available
                    if environment.featureFlags.enableRemoteCampusConfig,
                       let remoteConfig = contentService.remoteCampusConfig {
                        CampusConfigProvider.applyRemoteConfig(remoteConfig)
                    }
                    // Overlay remote events, pins, and collectibles onto ModelController
                    switch contentService.syncState {
                    case .synced, .stale:
                        modelController.applyRemoteContent(from: contentService)
                    default:
                        break
                    }
                }
                .preferredColorScheme(.light)
        }
    }
}
