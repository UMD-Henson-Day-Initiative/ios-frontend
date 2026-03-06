// HensonDayApp.swift

import SwiftUI

struct HensonDayApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()          // instead of a bare AR ContentView
                .environmentObject(appState)
        }
    }
}
