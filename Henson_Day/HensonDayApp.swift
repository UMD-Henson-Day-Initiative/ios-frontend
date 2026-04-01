// HensonDayApp.swift

import SwiftUI

@main
struct HensonDayApp: App {
    @StateObject private var modelController = ModelController()
    @StateObject private var tabRouter = TabRouter()

    var body: some Scene {
        WindowGroup {
            LaunchGateView()
                .environmentObject(modelController)
                .environmentObject(tabRouter)
        }
    }
}
