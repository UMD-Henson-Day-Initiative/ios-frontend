import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine

struct ARCollectibleExperienceView: View {
    enum FlowState {
        case tooFar
        case waitingForSecondSurface
        case detectSurface
        case placed
        case alreadyCollected
        case collecting
        case captured
        case noCollectiblesConfigured
    }

    let pin: PinEntity
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: FlowState = .tooFar
    @State private var surfaceDetected = false
    @State private var hasPlaced = false
    @State private var didTapCollectible = false
    @State private var isWithinSpawnRadius = false
    @State private var distanceMeters: Double?
    @State private var activeCollectible: DatabaseCollectible?
    @State private var secondHorizontalSurfaceDetected = false
    @State private var teleportFallbackReady = false

    // Global AR spawn radius in meters. Keep this low while testing close-range interactions.
    private let spawnRadiusMeters: CLLocationDistance = 5

    private var collectibleName: String {
        activeCollectible?.name ?? (pin.collectibleName ?? pin.title)
    }

    private var collectibleModelAssetName: String {
        activeCollectible?.modelFileName ?? "robot"
    }

    private var collectibleRarity: String {
        activeCollectible?.rarity ?? (pin.collectibleRarity ?? "Common")
    }

    private var collectiblePoints: Int {
        activeCollectible?.points ?? 50
    }

    private var formattedDistance: String {
        guard let distanceMeters else { return "--" }
        return "\(Int(distanceMeters.rounded())) m"
    }

    private var locationModeLabel: String {
        locationManager.testingOverrideCoordinate == nil ? "LIVE" : "TESTING OVERRIDE"
    }

    private var debugCollectibleID: String {
        activeCollectible.map { "ID: \($0.id)" } ?? "ID: none"
    }

    private var debugSpawnPath: String {
        guard isTeleportFlow else { return "via: proximity" }
        if secondHorizontalSurfaceDetected { return "via: 2nd surface" }
        if teleportFallbackReady { return "via: 10s fallback" }
        return "via: waiting…"
    }

    private var isTeleportFlow: Bool {
        locationManager.testingOverrideCoordinate != nil
    }

    private var alreadyCollected: Bool {
        modelController.hasCollectedCollectible(named: collectibleName)
    }

    // Teleport flow: spawn only after second detected horizontal surface OR after 10 seconds.
    private var teleportSpawnGateSatisfied: Bool {
        !isTeleportFlow || secondHorizontalSurfaceDetected || teleportFallbackReady
    }

    private var canSpawnCollectible: Bool {
        isWithinSpawnRadius && !alreadyCollected && activeCollectible != nil && teleportSpawnGateSatisfied
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: canSpawnCollectible,
                shouldForceSpawnWithoutSurface: isTeleportFlow && teleportFallbackReady && !secondHorizontalSurfaceDetected,
                modelAssetName: collectibleModelAssetName,
                surfaceDetected: $surfaceDetected,
                hasPlaced: $hasPlaced,
                didTapCollectible: $didTapCollectible,
                secondHorizontalSurfaceDetected: $secondHorizontalSurfaceDetected
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(collectibleName)
                            .font(.headline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())

                        Text(locationModeLabel)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())

                        Text(debugCollectibleID)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .foregroundStyle(.white.opacity(0.85))
                            .clipShape(Capsule())

                        Text(debugSpawnPath)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .foregroundStyle(.white.opacity(0.85))
                            .clipShape(Capsule())

                        Text("dist: \(formattedDistance)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .foregroundStyle(.white.opacity(0.85))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
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

                Spacer()

                overlayCard
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }

            if flowState == .collecting || flowState == .captured {
                captureAnimationOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            chooseCollectibleForCurrentPin()
            recalculateProximityAndFlow()

            // Teleport support: if only one surface is found, allow spawn after 10 seconds.
            if isTeleportFlow {
                teleportFallbackReady = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    teleportFallbackReady = true
                    recalculateProximityAndFlow()
                }
            }
        }
        .onReceive(locationManager.$currentCoordinate.combineLatest(locationManager.$testingOverrideCoordinate)) { _ in
            recalculateProximityAndFlow()
        }
        .onChange(of: surfaceDetected) { _, _ in
            recalculateProximityAndFlow()
        }
        .onChange(of: hasPlaced) { _, _ in
            recalculateProximityAndFlow()
        }
        .onChange(of: secondHorizontalSurfaceDetected) { _, _ in
            recalculateProximityAndFlow()
        }
        .onChange(of: didTapCollectible) { _, tapped in
            guard tapped, flowState == .placed, !alreadyCollected else { return }
            handleCollectTapped()
        }
    }

    @ViewBuilder
    private var overlayCard: some View {
        switch flowState {
        case .noCollectiblesConfigured:
            promptCard(
                title: "No collectibles configured for this pin",
                subtitle: "Add collectible IDs to this pin in Database.pins to enable AR spawns."
            ) {
                EmptyView()
            }
        case .tooFar:
            promptCard(
                title: "Move closer to unlock this collectible",
                subtitle: "Current distance: \(formattedDistance). Get within \(Int(spawnRadiusMeters)) m of \(pin.title)."
            ) {
                EmptyView()
            }
        case .waitingForSecondSurface:
            promptCard(
                title: "Collectible nearby",
                subtitle: "Teleport mode active. It appears on the second horizontal surface, or automatically after 10 seconds."
            ) {
                EmptyView()
            }
        case .detectSurface:
            promptCard(
                title: "\(collectibleName) is nearby!",
                subtitle: "Look around for a horizontal surface to place the model."
            ) {
                EmptyView()
            }
        case .placed:
            promptCard(title: collectibleName, subtitle: "Tap the 3D model to collect +\(collectiblePoints) points.") {
                EmptyView()
            }
        case .alreadyCollected:
            promptCard(title: "Already collected", subtitle: "You already captured \(collectibleName).") {
                Button("Go to Gallery") {
                    tabRouter.selectedTab = .collection
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("UMDRed"))
            }
        case .collecting:
            promptCard(title: "Collecting \(collectibleName)...", subtitle: "Nice find. Finalizing your capture.") {
                EmptyView()
            }
        case .captured:
            promptCard(
                title: "You collected \(collectibleName)! +\(collectiblePoints) pts",
                subtitle: "Sending you to your gallery now."
            ) {
                EmptyView()
            }
        }
    }

    private var captureAnimationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Color("UMDGold"))
                    .scaleEffect(flowState == .collecting ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatCount(2, autoreverses: true), value: flowState)

                Text("Collected!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(collectibleName)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(26)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func chooseCollectibleForCurrentPin() {
        let collectedNames = Set(modelController.collectionItemsForCurrentUser().map(\.collectibleName))

        let pinCollectibleIDs = Database.pins.first(where: { $0.title == pin.title })?.collectibleIDs ?? []
        var candidates = Database.collectibleCatalog.filter { pinCollectibleIDs.contains($0.id) }

        // Backward-compatible fallback for pins still configured by `collectibleName` only.
        if candidates.isEmpty, let fallbackName = pin.collectibleName {
            candidates = Database.collectibleCatalog.filter { $0.name == fallbackName }
        }

        let notCollected = candidates.filter { !collectedNames.contains($0.name) }
        activeCollectible = (notCollected.isEmpty ? candidates : notCollected).randomElement()
    }

    private func recalculateProximityAndFlow() {
        guard activeCollectible != nil else {
            flowState = .noCollectiblesConfigured
            return
        }

        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)

        if let userCoordinate = locationManager.effectiveCoordinate {
            let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
            let distance = userLocation.distance(from: pinLocation)
            distanceMeters = distance
            isWithinSpawnRadius = distance <= spawnRadiusMeters
        } else {
            distanceMeters = nil
            isWithinSpawnRadius = false
        }

        guard !alreadyCollected else {
            flowState = .alreadyCollected
            return
        }

        guard isWithinSpawnRadius else {
            flowState = .tooFar
            return
        }

        guard teleportSpawnGateSatisfied else {
            flowState = .waitingForSecondSurface
            return
        }

        if hasPlaced {
            flowState = .placed
        } else {
            flowState = .detectSurface
        }
    }

    private func handleCollectTapped() {
        flowState = .collecting

        modelController.captureCollectible(
            collectibleName: collectibleName,
            rarity: collectibleRarity,
            foundAtTitle: pin.title,
            points: collectiblePoints
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            flowState = .captured
            tabRouter.selectedTab = .collection

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                dismiss()
            }
        }
    }

    private func promptCard<Content: View>(title: String, subtitle: String, @ViewBuilder actions: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            actions()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ARPlacementView: UIViewRepresentable {
    let canSpawnCollectible: Bool
    let shouldForceSpawnWithoutSurface: Bool
    let modelAssetName: String
    @Binding var surfaceDetected: Bool
    @Binding var hasPlaced: Bool
    @Binding var didTapCollectible: Bool
    @Binding var secondHorizontalSurfaceDetected: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        context.coordinator.didTapCollectible = { didTapCollectible = true }
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.didTapCollectible = { didTapCollectible = true }
        context.coordinator.syncState(
            arView: uiView,
            canSpawnCollectible: canSpawnCollectible,
            shouldForceSpawnWithoutSurface: shouldForceSpawnWithoutSurface,
            modelAssetName: modelAssetName,
            surfaceDetected: $surfaceDetected,
            hasPlaced: $hasPlaced,
            secondHorizontalSurfaceDetected: $secondHorizontalSurfaceDetected
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?
        private var collectibleAnchor: AnchorEntity?
        private var collectibleEntity: Entity?
        private var currentModelAssetName: String?
        private var loadCancellable: AnyCancellable?
        private var horizontalPlaneAnchorCount = 0
        private var isCollectAnimationRunning = false
        var didTapCollectible: (() -> Void)?

        private let collectibleEntityName = "ar.collectible.entity"
        private let defaultTargetMaxDimension: Float = 0.20
        private let smallCollectibleTargetMaxDimension: Float = 0.14
        private let largeCollectibleTargetMaxDimension: Float = 0.25

        // Long-term sizing control by asset: mix smaller/larger target footprints.
        private let targetDimensionByModelAsset: [String: Float] = [
            "toy_car": 0.14,
            "hummingbird_anim": 0.14,
            "robot": 0.25,
            "toy_biplane_realistic": 0.25,
            "slide": 0.20
        ]

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.session.delegate = self

            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)
        }

        func syncState(
            arView: ARView,
            canSpawnCollectible: Bool,
            shouldForceSpawnWithoutSurface: Bool,
            modelAssetName: String,
            surfaceDetected: Binding<Bool>,
            hasPlaced: Binding<Bool>,
            secondHorizontalSurfaceDetected: Binding<Bool>
        ) {
            self.arView = arView
            secondHorizontalSurfaceDetected.wrappedValue = horizontalPlaneAnchorCount >= 2

            if !canSpawnCollectible {
                removeCollectibleIfNeeded()
                surfaceDetected.wrappedValue = false
                hasPlaced.wrappedValue = false
                return
            }

            // Keep the collectible anchored in world space once placed so it doesn't
            // drift with camera movement as `updateUIView` runs repeatedly.
            if collectibleAnchor != nil {
                surfaceDetected.wrappedValue = true
                hasPlaced.wrappedValue = collectibleEntity != nil
                return
            }

            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let raycastResults = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)

            if let result = raycastResults.first {
                surfaceDetected.wrappedValue = true
                placeOrMoveCollectible(using: result.worldTransform, modelAssetName: modelAssetName)
                hasPlaced.wrappedValue = collectibleEntity != nil
            } else if shouldForceSpawnWithoutSurface {
                // Teleport fallback path: place collectible in front of camera after timeout.
                surfaceDetected.wrappedValue = true
                placeCollectibleInFrontOfCamera(modelAssetName: modelAssetName)
                hasPlaced.wrappedValue = collectibleEntity != nil
            } else {
                surfaceDetected.wrappedValue = false
                hasPlaced.wrappedValue = false
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            let newHorizontalCount = anchors.compactMap { $0 as? ARPlaneAnchor }
                .filter { $0.alignment == .horizontal }
                .count
            horizontalPlaneAnchorCount += newHorizontalCount
        }

        private func placeOrMoveCollectible(using worldTransform: simd_float4x4, modelAssetName: String) {
            guard let arView else { return }

            let translation = worldTransform.translation
            let targetPosition = SIMD3<Float>(translation.x, translation.y, translation.z)

            if collectibleAnchor == nil {
                let anchor = AnchorEntity(world: targetPosition)
                collectibleAnchor = anchor
                arView.scene.addAnchor(anchor)
            }

            guard collectibleEntity == nil || currentModelAssetName != modelAssetName else { return }

            collectibleAnchor?.children.removeAll()
            collectibleEntity = nil
            currentModelAssetName = modelAssetName

            loadCancellable = Entity.loadModelAsync(named: modelAssetName)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure = completion {
                        self.installFallbackEntity()
                    }
                }, receiveValue: { [weak self] entity in
                    guard let self else { return }

                    entity.name = self.collectibleEntityName
                    let targetDimension = self.targetMaxDimension(for: modelAssetName)
                    entity.scale = self.normalizedScale(for: entity, targetMaxDimension: targetDimension)
                    entity.generateCollisionShapes(recursive: true)
                    entity.components.set(InputTargetComponent())

                    self.collectibleAnchor?.addChild(entity)
                    self.collectibleEntity = entity
                })
        }

        private func placeCollectibleInFrontOfCamera(modelAssetName: String) {
            guard let arView else { return }
            let cameraTransform = arView.cameraTransform.matrix
            let forward = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let fallbackPosition = cameraPosition + normalize(forward) * 0.9

            var fallbackTransform = matrix_identity_float4x4
            fallbackTransform.columns.3 = SIMD4<Float>(fallbackPosition.x, fallbackPosition.y, fallbackPosition.z, 1)
            placeOrMoveCollectible(using: fallbackTransform, modelAssetName: modelAssetName)
        }

        private func installFallbackEntity() {
            let fallbackMesh = MeshResource.generateSphere(radius: 0.12)
            let fallbackMaterial = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: false)
            let fallbackEntity = ModelEntity(mesh: fallbackMesh, materials: [fallbackMaterial])
            fallbackEntity.name = collectibleEntityName
            fallbackEntity.scale = SIMD3<Float>(repeating: 0.6)
            fallbackEntity.generateCollisionShapes(recursive: true)
            fallbackEntity.components.set(InputTargetComponent())
            collectibleAnchor?.addChild(fallbackEntity)
            collectibleEntity = fallbackEntity
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
            if let mapped = targetDimensionByModelAsset[modelAssetName] {
                return mapped
            }

            if modelAssetName.contains("toy_") {
                return smallCollectibleTargetMaxDimension
            }

            if modelAssetName.contains("robot") || modelAssetName.contains("biplane") {
                return largeCollectibleTargetMaxDimension
            }

            return defaultTargetMaxDimension
        }

        private func removeCollectibleIfNeeded() {
            collectibleEntity = nil
            currentModelAssetName = nil
            loadCancellable?.cancel()
            loadCancellable = nil

            if let collectibleAnchor {
                collectibleAnchor.removeFromParent()
                self.collectibleAnchor = nil
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)
            guard let hitEntity = arView.entity(at: location) else { return }

            let tappedCollectible = sequence(first: hitEntity, next: { $0.parent })
                .contains(where: { $0.name == collectibleEntityName })

            if tappedCollectible {
                animateCollectibleTowardCameraAndCollect()
            }
        }

        private func animateCollectibleTowardCameraAndCollect() {
            guard !isCollectAnimationRunning else { return }
            guard let arView, let collectibleEntity else {
                didTapCollectible?()
                return
            }

            isCollectAnimationRunning = true

            let cameraMatrix = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(
                cameraMatrix.columns.3.x,
                cameraMatrix.columns.3.y,
                cameraMatrix.columns.3.z
            )
            let forward = normalize(SIMD3<Float>(
                -cameraMatrix.columns.2.x,
                -cameraMatrix.columns.2.y,
                -cameraMatrix.columns.2.z
            ))
            let up = normalize(SIMD3<Float>(
                cameraMatrix.columns.1.x,
                cameraMatrix.columns.1.y,
                cameraMatrix.columns.1.z
            ))

            let targetPosition = cameraPosition + (forward * 0.18) - (up * 0.06)
            let currentScale = collectibleEntity.scale(relativeTo: nil)
            let targetScale = currentScale * SIMD3<Float>(repeating: 0.05)
            let targetTransform = Transform(
                scale: targetScale,
                rotation: collectibleEntity.orientation(relativeTo: nil),
                translation: targetPosition
            )

            collectibleEntity.move(
                to: targetTransform,
                relativeTo: nil,
                duration: 0.45,
                timingFunction: .easeInOut
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { [weak self] in
                guard let self else { return }
                collectibleEntity.removeFromParent()
                self.collectibleEntity = nil
                self.didTapCollectible?()
                self.isCollectAnimationRunning = false
            }
        }
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
