import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import CoreLocation
import Combine

struct ARCameraView: View {
    let isCameraAuthorized: Bool
    let worldAnchorManager: WorldAnchorManager
    let availableCollectibles: [DatabaseCollectible]
    /// Set to true while another AR session (e.g. ARCollectibleExperienceView) is active.
    /// This pauses the session so the two ARViews don't fight over the camera.
    var isPaused: Bool = false
    var showPlacementControls: Bool = true

    @StateObject private var placementState = PlacementState()
    @State private var isPickerPresented = false

    init(
        isCameraAuthorized: Bool,
        worldAnchorManager: WorldAnchorManager,
        availableCollectibles: [DatabaseCollectible] = [],
        isPaused: Bool = false,
        showPlacementControls: Bool = true
    ) {
        self.isCameraAuthorized = isCameraAuthorized
        self.worldAnchorManager = worldAnchorManager
        self.availableCollectibles = availableCollectibles
        self.isPaused = isPaused
        self.showPlacementControls = showPlacementControls
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ARCameraRepresentable(
                isCameraAuthorized: isCameraAuthorized,
                isPaused: isPaused,
                worldAnchorManager: worldAnchorManager,
                placementState: placementState
            )

            if showPlacementControls {
                placementControls
                    .padding(.trailing, 14)
                    .padding(.bottom, 126)
            }
        }
        .onAppear {
            placementState.availableCollectibles = availableCollectibles
            if placementState.selectedCollectible == nil {
                placementState.selectedCollectible = availableCollectibles.first
            }
        }
        .onChange(of: availableCollectibles.map(\.id)) { _, _ in
            placementState.availableCollectibles = availableCollectibles

            if let selected = placementState.selectedCollectible,
               !availableCollectibles.contains(where: { $0.id == selected.id }) {
                placementState.selectedCollectible = availableCollectibles.first
                placementState.isPlacementArmed = false
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            CollectiblePickerSheet(
                collectibles: placementState.availableCollectibles,
                selectedCollectibleID: placementState.selectedCollectible?.id,
                onPick: { collectible in
                    placementState.selectedCollectible = collectible
                    placementState.isPlacementArmed = false
                    placementState.statusMessage = "Selected \(collectible.name). Tap the token to arm placement."
                    isPickerPresented = false
                }
            )
        }
    }

    private var placementControls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Button("Place") {
                isPickerPresented = true
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .clipShape(Capsule())

            Button {
                guard placementState.selectedCollectible != nil else {
                    placementState.statusMessage = "Pick a collectible first."
                    return
                }
                placementState.isPlacementArmed.toggle()
            } label: {
                CollectibleTokenView(collectible: placementState.selectedCollectible)
                    .overlay(
                        Circle()
                            .stroke(
                                placementState.isPlacementArmed ? Color("UMDGold") : Color.white.opacity(0.7),
                                lineWidth: placementState.isPlacementArmed ? 4 : 2
                            )
                    )
                    .shadow(radius: 5)
            }
            .buttonStyle(.plain)

            Text("Placed: \(placementState.placedCount)/3")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.thinMaterial)
                .clipShape(Capsule())

            Button("Clear All Placed") {
                placementState.clearAllRequestCount += 1
                placementState.statusMessage = "Cleared placed models."
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())

            if let statusMessage = placementState.statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(maxWidth: 210, alignment: .trailing)
            }
        }
    }
}

private struct ARCameraRepresentable: UIViewRepresentable {
    let isCameraAuthorized: Bool
    let isPaused: Bool
    let worldAnchorManager: WorldAnchorManager
    @ObservedObject var placementState: PlacementState

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.environment.sceneUnderstanding.options = []
        context.coordinator.configureSessionIfPossible(on: arView, isCameraAuthorized: isCameraAuthorized, isPaused: isPaused)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.configureSessionIfPossible(on: uiView, isCameraAuthorized: isCameraAuthorized, isPaused: isPaused)
        context.coordinator.updatePlacementState(placementState)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(worldAnchorManager: worldAnchorManager, placementState: placementState)
    }

    final class Coordinator: NSObject {
        private var hasConfigured = false
        private let worldAnchorManager: WorldAnchorManager
        private weak var arView: ARView?
        private var placementState: PlacementState

        private struct PlacedAnchor {
            let anchor: AnchorEntity
            let origin: SIMD3<Float>
        }

        private var placedAnchors: [PlacedAnchor] = []
        private let maxPlacements = 3
        private let walkAwayDistanceMeters: Float = 12
        private var lastHandledClearAllRequestCount = 0

        init(worldAnchorManager: WorldAnchorManager, placementState: PlacementState) {
            self.worldAnchorManager = worldAnchorManager
            self.placementState = placementState
        }

        func updatePlacementState(_ placementState: PlacementState) {
            self.placementState = placementState

            if placementState.clearAllRequestCount != lastHandledClearAllRequestCount {
                lastHandledClearAllRequestCount = placementState.clearAllRequestCount
                clearPlacedAnchors()
            }
        }

        func configureSessionIfPossible(on arView: ARView, isCameraAuthorized: Bool, isPaused: Bool = false) {
            self.arView = arView

            // Yield the camera to another AR session (e.g. ARCollectibleExperienceView).
            if isPaused {
                arView.session.pause()
                hasConfigured = false  // Force a fresh restart when unpaused.
                clearPlacedAnchors()
                return
            }

            guard isCameraAuthorized else {
                arView.session.pause()
                hasConfigured = false
                clearPlacedAnchors()
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
                arView.session.delegate = self
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                arView.addGestureRecognizer(tapGesture)
                _ = worldAnchorManager
                hasConfigured = true
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard placementState.isPlacementArmed else { return }
            guard let selected = placementState.selectedCollectible else {
                placementState.statusMessage = "Select a collectible with Place first."
                return
            }

            guard placedAnchors.count < maxPlacements else {
                placementState.statusMessage = "Max of three placed."
                return
            }

            guard let arView else { return }
            let tapLocation = recognizer.location(in: arView)
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)

            guard let firstResult = results.first else {
                placementState.statusMessage = "Aim at a horizontal surface."
                return
            }

            guard let modelEntity = try? ModelEntity.loadModel(named: selected.modelFileName) else {
                placementState.statusMessage = "Couldn't load \(selected.modelFileName).usdz"
                return
            }

            modelEntity.scale = normalizedScale(for: modelEntity, targetMaxDimension: targetMaxDimension(for: selected.modelFileName))
            modelEntity.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: firstResult.worldTransform)
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)

            let translation = firstResult.worldTransform.translation
            placedAnchors.append(.init(anchor: anchor, origin: translation))

            placementState.placedCount = placedAnchors.count
            placementState.statusMessage = "Placed \(selected.name)."

            if placedAnchors.count >= maxPlacements {
                placementState.isPlacementArmed = false
                placementState.statusMessage = "Max of three placed."
            }
        }

        private func clearPlacedAnchors() {
            for entry in placedAnchors {
                entry.anchor.removeFromParent()
            }
            placedAnchors.removeAll()
            placementState.placedCount = 0
            placementState.isPlacementArmed = false
        }

        private func normalizedScale(for entity: Entity, targetMaxDimension: Float) -> SIMD3<Float> {
            let bounds = entity.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            let maxDimension = max(extents.x, max(extents.y, extents.z))
            guard maxDimension.isFinite, maxDimension > 0 else {
                return SIMD3<Float>(repeating: 0.12)
            }

            let uniformScale = targetMaxDimension / maxDimension
            let clampedScale = min(max(uniformScale, 0.03), 0.35)
            return SIMD3<Float>(repeating: clampedScale)
        }

        private func targetMaxDimension(for modelAssetName: String) -> Float {
            if modelAssetName.contains("toy_") { return 0.14 }
            if modelAssetName.contains("robot") || modelAssetName.contains("biplane") { return 0.25 }
            return 0.20
        }
    }
}

extension ARCameraRepresentable.Coordinator: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        let toRemove = placedAnchors.filter { placed in
            simd_distance(placed.origin, cameraPosition) > walkAwayDistanceMeters
        }

        guard !toRemove.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            for entry in toRemove {
                entry.anchor.removeFromParent()
            }

            self.placedAnchors.removeAll { current in
                toRemove.contains { $0.anchor == current.anchor }
            }

            self.placementState.placedCount = self.placedAnchors.count
            self.placementState.statusMessage = "Removed distant placed models."
        }
    }
}

private final class PlacementState: ObservableObject {
    @Published var availableCollectibles: [DatabaseCollectible] = []
    @Published var selectedCollectible: DatabaseCollectible?
    @Published var isPlacementArmed = false
    @Published var statusMessage: String?
    @Published var placedCount = 0
    @Published var clearAllRequestCount = 0
}

private struct CollectiblePickerSheet: View {
    let collectibles: [DatabaseCollectible]
    let selectedCollectibleID: String?
    let onPick: (DatabaseCollectible) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if collectibles.isEmpty {
                    ContentUnavailableView(
                        "No Collected Items",
                        systemImage: "cube.box",
                        description: Text("Capture collectibles first, then place them in camera mode.")
                    )
                } else {
                    List(collectibles) { collectible in
                        Button {
                            onPick(collectible)
                        } label: {
                            HStack(spacing: 12) {
                                CollectibleTokenView(collectible: collectible)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collectible.name)
                                        .font(.headline)
                                    Text("\(collectible.rarity) • +\(collectible.points) pts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedCollectibleID == collectible.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color("UMDRed"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose Collectible")
        }
    }
}

private struct CollectibleTokenView: View {
    let collectible: DatabaseCollectible?

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            if let collectible {
                Text(String(collectible.name.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color("UMDRed"))
            } else {
                Circle()
                    .stroke(.white.opacity(0.7), lineWidth: 2)
                    .padding(8)
            }
        }
        .frame(width: 56, height: 56)
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
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
            DispatchQueue.main.async {
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

