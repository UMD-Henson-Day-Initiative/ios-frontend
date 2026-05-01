import SwiftUI

struct AppEntryView: View {
    @EnvironmentObject private var authController: AuthController

    var body: some View {
        Group {
            if authController.isAuthenticated {
                LaunchGateView()
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    AppEntryView()
        .environmentObject(AuthController())
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
        .environmentObject(CameraPermissionManager())
        .environmentObject(WorldAnchorManager())
        .environmentObject(LocationPermissionManager())
        .environmentObject(ContentService(environment: .development))
}