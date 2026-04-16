import SwiftUI
import AVFoundation
import CoreLocation
import Combine
import os

/// App startup gate that checks camera and location permissions before allowing
/// entry to the main app. Shows permission status, content sync progress, handles
/// retry/settings flow, and waits for ModelController to finish seeding before
/// transitioning to RootTabView.
struct LaunchGateView: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var contentService: ContentService
    @StateObject private var permissionState = LaunchPermissionState()
    @State private var hasEnteredApp = false

    private let logger = AppLogger.make(.startup)

    /// True when both local seed and content service have finished their initial work.
    private var isStartupComplete: Bool {
        !modelController.isSeedLoading && contentService.hasUsableContent
    }

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
            logger.info("Launch gate appeared")
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
                    startupErrorView(message: startupErrorMessage)
                } else {
                    if let startupNoticeMessage = modelController.startupNoticeMessage {
                        startupNoticeView(message: startupNoticeMessage)
                    }

                    // Permissions
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

                    // Content sync status
                    contentSyncStatusView

                    if permissionState.anyDenied {
                        Button("Open Settings") {
                            permissionState.openSettings()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Enter Map") {
                        logger.info("User entered app. Sync state: \(String(describing: contentService.syncState))")
                        hasEnteredApp = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("UMDRed"))
                    .padding(.top, 4)
                    .disabled(!isStartupComplete)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Startup error (SwiftData failed)

    private func startupErrorView(message: String) -> some View {
        VStack(spacing: 10) {
            Label("Offline data failed to load", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            Text(message)
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
    }

    private func startupNoticeView(message: String) -> some View {
        VStack(spacing: 8) {
            Label("Demo mode active", systemImage: "internaldrive.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("UMDRed"))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    // MARK: - Content sync status

    @ViewBuilder
    private var contentSyncStatusView: some View {
        switch contentService.syncState {
        case .idle, .loadingBundle:
            ProgressView("Loading content")
                .font(.caption)
                .padding(.top, 4)
        case .syncingRemote:
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking for content updates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if contentService.hasRemoteOverlayContent {
                    Text("Showing cached content while the latest updates load.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                contentSyncFeedbackView
            }
            .padding(.top, 4)
        case .synced:
            VStack(spacing: 6) {
                Label("Content up to date", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                contentSyncFeedbackView
            }
            .padding(.top, 4)
        case .bundleOnly(let reason):
            VStack(spacing: 6) {
                Label("Using offline content", systemImage: "internaldrive.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 4)
        case .stale:
            VStack(spacing: 6) {
                Label("Content may be outdated", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
                contentSyncFeedbackView
                Button("Retry Sync") {
                    Task { await contentService.refreshFromRemote() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        case .failed(let message):
            VStack(spacing: 6) {
                Label("Content sync failed", systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
                contentSyncFeedbackView
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await contentService.refreshFromRemote() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var contentSyncFeedbackView: some View {
        if let feedback = contentService.syncFeedback {
            VStack(spacing: 4) {
                Label(feedback.title, systemImage: syncFeedbackIcon(for: feedback.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(syncFeedbackColor(for: feedback.kind))

                if let message = feedback.message, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func syncFeedbackColor(for kind: ContentService.ContentSyncFeedback.Kind) -> Color {
        switch kind {
        case .info:
            return Color("UMDRed")
        case .success:
            return .green
        case .warning:
            return .orange
        }
    }

    private func syncFeedbackIcon(for kind: ContentService.ContentSyncFeedback.Kind) -> String {
        switch kind {
        case .info:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .success:
            return "checkmark.seal.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - Shared row

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

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationStatus = manager.authorizationStatus
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
