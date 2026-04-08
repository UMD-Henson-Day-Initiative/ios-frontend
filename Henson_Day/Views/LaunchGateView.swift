import SwiftUI
import AVFoundation
import CoreLocation
import Combine

/// App startup gate that checks camera and location permissions before allowing
/// entry to the main app. Shows permission status, handles retry/settings flow,
/// and waits for ModelController to finish seeding before transitioning to RootTabView.
struct LaunchGateView: View {
    @EnvironmentObject private var modelController: ModelController
    @StateObject private var permissionState = LaunchPermissionState()
    @State private var hasEnteredApp = false

    var body: some View {
        Group {
            if hasEnteredApp {
                RootTabView()
            } else {
                launchContent
            }
        }
        .onAppear {
            permissionState.refreshAndRequestIfNeeded()
        }
    }

    private var launchContent: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Henson Day")
                    .font(.largeTitle.weight(.bold))

                Text("Campus AR Scavenger Hunt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if modelController.isSeedLoading {
                    ProgressView("Preparing offline data")
                        .padding(.top, 8)
                } else if let startupErrorMessage = modelController.startupErrorMessage {
                    VStack(spacing: 10) {
                        Label("Offline data failed to load", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)

                        Text(startupErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            modelController.retryInitialization()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("UMDRed"))
                        .padding(.top, 4)
                    }
                    .padding(.top, 6)
                } else {
                    VStack(spacing: 10) {
                        permissionRow(
                            title: "Location",
                            granted: permissionState.locationGranted,
                            denied: permissionState.locationDenied,
                            icon: "location.fill"
                        )
                        permissionRow(
                            title: "Camera",
                            granted: permissionState.cameraGranted,
                            denied: permissionState.cameraDenied,
                            icon: "camera.fill"
                        )
                    }
                    .padding(.top, 6)

                    if permissionState.anyDenied {
                        Button("Open Settings") {
                            permissionState.openSettings()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Enter Map") {
                        hasEnteredApp = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("UMDRed"))
                    .padding(.top, 4)
                }
            }
            .padding(24)
        }
    }

    private func permissionRow(title: String, granted: Bool, denied: Bool, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if granted {
                Text("Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if denied {
                Text("Denied")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    LaunchGateView()
        .environmentObject(ModelController.preview())
}

final class LaunchPermissionState: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var cameraStatus: AVAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    var locationGranted: Bool {
        locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
    }

    var locationDenied: Bool {
        locationStatus == .denied || locationStatus == .restricted
    }

    var cameraGranted: Bool {
        cameraStatus == .authorized
    }

    var cameraDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted
    }

    var anyDenied: Bool {
        locationDenied || cameraDenied
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func refreshAndRequestIfNeeded() {
        locationStatus = locationManager.authorizationStatus
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if locationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor in
                    self?.cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
