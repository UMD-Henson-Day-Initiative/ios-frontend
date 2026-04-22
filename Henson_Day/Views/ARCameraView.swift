//  ARCameraView.swift
//  Henson_Day
//
//  File Description: This file manages the augmented reality camera experience for the Henson Day
//  app. It handles AR session configuration, collectible placement in the real world via tap gestures,
//  camera permission management, and world anchor management. It includes the main ARCameraView,
//  a UIViewRepresentable bridge to RealityKit's ARView, a collectible picker sheet, and supporting
//  managers for camera permissions and world anchors.
//

import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import CoreLocation
import Combine

struct ARCameraView: View {
    let isCameraAuthorized: Bool
    let worldAnchorManager: WorldAnchorManager
    /// Set to true while another AR session (e.g. ARCollectibleExperienceView) is active.
    /// This pauses the session so the two ARViews don't fight over the camera.
    var isPaused: Bool = false

    var body: some View {
        ARCameraRepresentable(
            isCameraAuthorized: isCameraAuthorized,
            isPaused: isPaused,
            worldAnchorManager: worldAnchorManager
        )
    }
}

private struct ARCameraRepresentable: UIViewRepresentable {
    let isCameraAuthorized: Bool
    let isPaused: Bool
    let worldAnchorManager: WorldAnchorManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.environment.sceneUnderstanding.options = []
        context.coordinator.configureSessionIfPossible(on: arView, isCameraAuthorized: isCameraAuthorized, isPaused: isPaused)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.configureSessionIfPossible(on: uiView, isCameraAuthorized: isCameraAuthorized, isPaused: isPaused)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.reset()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(worldAnchorManager: worldAnchorManager)
    }

    final class Coordinator: NSObject {
        private var hasConfigured = false
        private let worldAnchorManager: WorldAnchorManager

        init(worldAnchorManager: WorldAnchorManager) {
            self.worldAnchorManager = worldAnchorManager
        }

        func reset() {
            hasConfigured = false
        }

        func configureSessionIfPossible(on arView: ARView, isCameraAuthorized: Bool, isPaused: Bool = false) {
            // Yield the camera to another AR session (e.g. ARCollectibleExperienceView).
            if isPaused {
                arView.session.pause()
                hasConfigured = false  // Force a fresh restart when unpaused.
                return
            }

            guard isCameraAuthorized else {
                arView.session.pause()
                hasConfigured = false
                return
            }

            guard ARWorldTrackingConfiguration.isSupported else {
                return
            }

            if !hasConfigured {
                let configuration = ARWorldTrackingConfiguration()
                configuration.worldAlignment = .gravity
                configuration.planeDetection = [.horizontal]

                arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                _ = worldAnchorManager
                hasConfigured = true
            }
        }
    }
}

final class CameraPermissionManager: ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus

    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestIfNeeded() {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = current

        guard current == .notDetermined else { return }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in
                self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}

struct CollectibleEntity: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D?
    let modelName: String

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D? = nil, modelName: String) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.modelName = modelName
    }

    static func == (lhs: CollectibleEntity, rhs: CollectibleEntity) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class WorldAnchorManager: ObservableObject {
    private let starterWallAnchorName = "starter.wall.anchor"
    @Published private(set) var collectibles: [CollectibleEntity] = []

    func installStarterWall(into arView: ARView) {
        guard arView.scene.anchors.first(where: { $0.name == starterWallAnchorName }) == nil else { return }

        let wallMesh = MeshResource.generateBox(width: 1.8, height: 1.8, depth: 0.04)
        let wallMaterial = SimpleMaterial(color: UIColor.systemRed.withAlphaComponent(0.85), roughness: 0.95, isMetallic: false)
        let wallEntity = ModelEntity(mesh: wallMesh, materials: [wallMaterial])
        wallEntity.name = "starter.wall"

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.0))
        anchor.name = starterWallAnchorName
        anchor.addChild(wallEntity)
        arView.scene.addAnchor(anchor)
    }

    func addCollectible(_ collectible: CollectibleEntity) {
        collectibles.append(collectible)
    }

    func clearCollectibles() {
        collectibles.removeAll()
    }
}
