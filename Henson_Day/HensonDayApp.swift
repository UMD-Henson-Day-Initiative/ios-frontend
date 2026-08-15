// HensonDayApp.swift

import SwiftUI

@main
struct HensonDayApp: App {
    @StateObject private var authManager: AuthManager
    @StateObject private var appSession: AppSession
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var cameraPermission = CameraPermissionManager()

    init() {
        let auth = AuthManager()
        _authManager = StateObject(wrappedValue: auth)
        _appSession = StateObject(wrappedValue: AppSession(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environmentObject(authManager)
                .environmentObject(appSession)
                .environmentObject(tabRouter)
                .environmentObject(locationManager)
                .environmentObject(cameraPermission)
                .onOpenURL { url in
                    AuthManager.handle(url: url)
                }
                .preferredColorScheme(.light)
        }
    }
}

/// Chooses between the splash state, sign-in, and the main app based on
/// Supabase's auth state, and drives AppSession's bootstrap/reset in response.
private struct RootGateView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appSession: AppSession

    var body: some View {
        Group {
            if authManager.isRestoringSession {
                SplashView()
            } else if authManager.session != nil {
                RootTabView()
            } else {
                SignInScreen()
            }
        }
        .onChange(of: authManager.session == nil) { _, isSignedOut in
            if isSignedOut {
                appSession.reset()
            } else {
                Task { await appSession.bootstrap() }
            }
        }
        .onChange(of: appSession.wrongDomainDetected) { _, isWrongDomain in
            guard isWrongDomain else { return }
            Task { await authManager.signOut() }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            DS.Color.surface.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text("Henson Day")
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.campusNight)
            }
        }
    }
}
