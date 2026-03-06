// AppDelegate.swift

import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    // Global state lives here and gets injected into SwiftUI
    let appState = AppState()
    let modelController = ModelController()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let rootView = RootTabView()
            .environmentObject(appState)
            .environmentObject(modelController)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()
        return true
    }

}
