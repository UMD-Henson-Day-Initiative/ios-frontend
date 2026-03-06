// HensonDayApp.swift

import SwiftUI

struct HensonDayApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var modelController = ModelController()

    var body: some Scene {
        WindowGroup {
            LaunchGateView()
                .environmentObject(appState)
                .environmentObject(modelController)
        }
    }
}
