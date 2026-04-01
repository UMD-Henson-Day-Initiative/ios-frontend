//
//  ARPhotoBoothView.swift
//  Henson_Day
//
//  Created by Colin Kurniawan on 3/16/26.
//

import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine

struct ARPhotoBoothView: View {

    enum FlowState {
        case tooFar
        case waitingForSecondSurface
        case detectSurface
        case ready
        case countdown
        case captured
    }

    let pin: PinEntity
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: FlowState = .tooFar
    @State private var surfaceDetected = false
    @State private var hasPlaced = false
    @State private var didTapCollectible = false
    @State private var isWithinRange = false
    @State private var distanceMeters: Double?
    @State private var activeCollectible: DatabaseCollectible?
    @State private var secondHorizontalSurfaceDetected = false
    @State private var teleportFallbackReady = false
    @State private var countdownValue = 3
    @State private var capturedImage: UIImage?
    @State private var showShareSheet = false

    private let spawnRadiusMeters: CLLocationDistance = 5

    private var collectibleName: String {
        activeCollectible?.name ?? (pin.collectibleName ?? pin.title)
    }

    private var collectibleModelAssetName: String {
        activeCollectible?.modelFileName ?? "robot"
    }

    private var collectiblePoints: Int {
        activeCollectible?.points ?? 50
    }

    private var collectibleRarity: String {
        activeCollectible?.rarity ?? (pin.collectibleRarity ?? "Common")
    }

    private var formattedDistance: String {
        guard let distanceMeters else { return "--" }
        return "\(Int(distanceMeters.rounded())) m"
    }

    private var isTeleportFlow: Bool {
        locationManager.testingOverrideCoordinate != nil
    }

    private var teleportSpawnGateSatisfied: Bool {
        !isTeleportFlow || secondHorizontalSurfaceDetected || teleportFallbackReady
    }

    private var canSpawn: Bool {
        isWithinRange && activeCollectible != nil && teleportSpawnGateSatisfied
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: canSpawn,
                shouldForceSpawnWithoutSurface: isTeleportFlow && teleportFallbackReady && !secondHorizontalSurfaceDetected,
                modelAssetName: collectibleModelAssetName,
                surfaceDetected: $surfaceDetected,
                hasPlaced: $hasPlaced,
                didTapCollectible: $didTapCollectible,
                secondHorizontalSurfaceDetected: $secondHorizontalSurfaceDetected
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomControls
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }

            if flowState == .countdown {
                countdownOverlay
            }

            if flowState == .captured, let image = capturedImage {
                capturedOverlay(image: image)
            }
        }
        .onAppear {
            chooseCollectible()
            recalculateFlow()

            if isTeleportFlow {
                teleportFallbackReady = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    teleportFallbackReady = true
                    recalculateFlow()
                }
            }
        }
        .onReceive(locationManager.$currentCoordinate.combineLatest(locationManager.$testingOverrideCoordinate)) { _ in
            recalculateFlow()
        }
        .onChange(of: surfaceDetected) { _, _ in recalculateFlow() }
        .onChange(of: hasPlaced) { _, _ in recalculateFlow() }
        .onChange(of: secondHorizontalSurfaceDetected) { _, _ in recalculateFlow() }
        .sheet(isPresented: $showShareSheet) {
            if let image = capturedImage {
                ShareSheet(image: image)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("📸 Photo with \(collectibleName)")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                if flowState == .tooFar {
                    Text("dist: \(formattedDistance)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.45))
                        .foregroundStyle(.white.opacity(0.85))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(10)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            statusCard

            if flowState == .ready {
                Button {
                    startCountdown()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                        Circle()
                            .strokeBorder(.white.opacity(0.4), lineWidth: 5)
                            .frame(width: 92, height: 92)
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: flowState)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch flowState {
        case .tooFar:
            promptCard(
                title: "Get closer to \(collectibleName)!",
                subtitle: "You're \(formattedDistance) away. Get within \(Int(spawnRadiusMeters))m."
            )
        case .waitingForSecondSurface:
            promptCard(
                title: "\(collectibleName) is nearby!",
                subtitle: "Teleport mode active. Waiting for second surface or 10 seconds."
            )
        case .detectSurface:
            promptCard(
                title: "\(collectibleName) is ready!",
                subtitle: "Point your camera at the ground to place them."
            )
        case .ready:
            promptCard(
                title: "Strike a pose!",
                subtitle: "Tap the shutter when you're ready for your photo."
            )
        case .countdown:
            promptCard(title: "Get ready...", subtitle: "Hold still!")
        case .captured:
            promptCard(
                title: "Photo taken! 🎉",
                subtitle: "Save or share your photo with \(collectibleName)."
            )
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        Text("\(countdownValue)")
            .font(.system(size: 120, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8)
            .id(countdownValue)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: countdownValue)
    }

    private func startCountdown() {
        flowState = .countdown
        countdownValue = 3

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownValue > 1 {
                countdownValue -= 1
            } else {
                timer.invalidate()
                takePhoto()
            }
        }
    }

    // MARK: - Photo Capture

    private func takePhoto() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else {
            flowState = .captured
            return
        }

        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        capturedImage = image
        flowState = .captured
    }

    // MARK: - Captured Overlay

    private func capturedOverlay(image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal)
                    .shadow(radius: 12)

                HStack(spacing: 16) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    } label: {
                        Label("Save", systemImage: "arrow.down.to.line")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.pink)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal)

                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Helpers

    private func promptCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chooseCollectible() {
        let pinCollectibleIDs = Database.pins.first(where: { $0.title == pin.title })?.collectibleIDs ?? []
        var candidates = Database.collectibleCatalog.filter { pinCollectibleIDs.contains($0.id) }

        if candidates.isEmpty, let fallbackName = pin.collectibleName {
            candidates = Database.collectibleCatalog.filter { $0.name == fallbackName }
        }

        activeCollectible = candidates.randomElement()
    }

    private func recalculateFlow() {
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)

        if let coord = locationManager.effectiveCoordinate {
            let userLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = userLocation.distance(from: pinLocation)
            distanceMeters = distance
            isWithinRange = distance <= spawnRadiusMeters
        } else {
            distanceMeters = nil
            isWithinRange = false
        }

        guard isWithinRange else { flowState = .tooFar; return }
        guard teleportSpawnGateSatisfied else {
            flowState = .waitingForSecondSurface
            return
        }

        // Don't override these states once we're in them
        if flowState == .ready || flowState == .countdown || flowState == .captured { return }
        flowState = hasPlaced ? .ready : .detectSurface
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
