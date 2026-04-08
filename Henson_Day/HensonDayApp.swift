// HensonDayApp.swift

import SwiftUI

@main
struct HensonDayApp: App {
    @StateObject private var modelController = ModelController()
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var cameraPermission = CameraPermissionManager()
    @StateObject private var worldAnchorManager = WorldAnchorManager()
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var contentService = ContentService()

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
                    await contentService.loadFromBundle()
                    await contentService.refreshFromRemoteIfAvailable()
                }
                .preferredColorScheme(.light)
        }
    }
}
