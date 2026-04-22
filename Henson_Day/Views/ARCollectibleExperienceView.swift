import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import QuartzCore

/// Full-screen AR experience for finding and collecting a muppet at a map pin.
///
/// **State machine flow:**
/// 1. `tooFar` — User is outside spawn radius; shows distance and direction.
/// 2. `detectSurface` / `waitingForSecondSurface` — User is close enough; AR session
///    searches for a horizontal surface to place the collectible.
/// 3. `placed` — Model is placed in the scene; user taps it to collect.
/// 4. `collecting` → `captured` — Capture animation plays, points are awarded via
///    `ModelController.captureCollectible(...)`, and the user is returned to the map.
/// 5. `alreadyCollected` — User already owns this collectible; shown a message.
/// 6. `noCollectiblesConfigured` — Pin has no collectible data; error state.
///
/// Teleport mode (DEBUG only) bypasses GPS proximity checks for testing.
struct ARCollectibleExperienceView: View {
    /// Tracks the user's progression through the AR collectible flow.
    enum FlowState {
        case tooFar
        case waitingForSecondSurface
        case guiding
        case readyToSpawn
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
    @State private var placementFallbackReady = false
    @State private var placementReadiness: Double = 0
    @State private var pointsBurstProgress: CGFloat = 1
    @State private var placementFallbackTask: Task<Void, Never>?
    @State private var collectFlowTask: Task<Void, Never>?

    // Show nearby collectible state within 30m.
    private let spawnRadiusMeters: CLLocationDistance = AppConstants.AR.spawnRadiusMeters

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
        activeCollectible?.points ?? AppConstants.AR.defaultCollectiblePoints
    }

    private var currentTotalPoints: Int {
        modelController.currentUser?.totalPoints ?? 0
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
        if placementFallbackReady { return "via: timed fallback" }
        return "via: waiting…"
    }

    private var isTeleportFlow: Bool {
        locationManager.testingOverrideCoordinate != nil
    }

    private var alreadyCollected: Bool {
        if let activeCollectible {
            return modelController.isCollectibleUnlocked(id: activeCollectible.id, name: activeCollectible.name)
        }

        return modelController.hasCollectedCollectible(named: collectibleName)
    }

    // Teleport flow: spawn only after second detected horizontal surface OR after 10 seconds.
    private var teleportSpawnGateSatisfied: Bool {
        !isTeleportFlow || secondHorizontalSurfaceDetected || placementFallbackReady
    }

    private var canSpawnCollectible: Bool {
        isWithinSpawnRadius && !alreadyCollected && activeCollectible != nil && teleportSpawnGateSatisfied
    }

    private var shouldForceSpawnWithoutSurface: Bool {
        placementFallbackReady && !hasPlaced && placementReadiness < 1
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: canSpawnCollectible,
                shouldForceSpawnWithoutSurface: shouldForceSpawnWithoutSurface,
                modelAssetName: collectibleModelAssetName,
                surfaceDetected: $surfaceDetected,
                hasPlaced: $hasPlaced,
                didTapCollectible: $didTapCollectible,
                secondHorizontalSurfaceDetected: $secondHorizontalSurfaceDetected,
                placementReadiness: $placementReadiness
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

                        Text("AR BETA")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color("UMDGold").opacity(0.88))
                            .foregroundStyle(.black.opacity(0.82))
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

                if flowState == .guiding || flowState == .readyToSpawn || flowState == .waitingForSecondSurface {
                    guidanceOverlay
                        .padding(.horizontal, 24)
                }

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

            placementFallbackReady = false
            placementFallbackTask?.cancel()
            placementFallbackTask = Task { @MainActor in
                let delay = isTeleportFlow
                    ? AppConstants.AR.teleportFallbackDelaySeconds
                    : AppConstants.AR.livePlacementFallbackDelaySeconds
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                placementFallbackReady = true
                recalculateProximityAndFlow()
            }
        }
        .onDisappear {
            placementFallbackTask?.cancel()
            collectFlowTask?.cancel()
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
        .onChange(of: placementReadiness) { _, _ in
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
                subtitle: "This pin does not currently map to any active collectible content."
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
                subtitle: "Teleport mode active. It appears on the second horizontal surface, or automatically after ~2 seconds."
            ) {
                EmptyView()
            }
        case .guiding:
            promptCard(
                title: "\(collectibleName) is nearby!",
                subtitle: surfaceDetected
                    ? "Hold steady on a clear patch of ground while the spirit scout locks in the spawn."
                    : "Tilt toward the ground and follow the pep-rally guide markers to find a landing spot."
            ) {
                EmptyView()
            }
        case .readyToSpawn:
            promptCard(
                title: "Hold steady...",
                subtitle: "Placement is nearly locked. Keep the guide centered for the collectible to appear."
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
                subtitle: "Unlocked in the UMD Index. Total points: \(currentTotalPoints)."
            ) {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var guidanceOverlay: some View {
        switch flowState {
        case .waitingForSecondSurface:
            ScoutGuidanceBanner(
                mode: .scan,
                title: "Scout the floor",
                subtitle: "Pan slowly until the guide finds a second horizontal surface."
            )
        case .guiding:
            ScoutGuidanceBanner(
                mode: surfaceDetected ? .holdSteady(progress: placementReadiness) : .scan,
                title: surfaceDetected ? "Pep squad is locking on" : "Sweep the ground",
                subtitle: surfaceDetected
                    ? "Keep the guide centered and steady."
                    : "Aim a little lower and move slowly to reveal a clear surface."
            )
        case .readyToSpawn:
            ScoutGuidanceBanner(
                mode: .holdSteady(progress: placementReadiness),
                title: "Target almost ready",
                subtitle: "Keep the center marker lined up for the drop."
            )
        default:
            EmptyView()
        }
    }

    private var captureAnimationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("+\(collectiblePoints)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Color("UMDGold"))
                    .shadow(color: Color("UMDGold").opacity(0.45), radius: 14, x: 0, y: 4)
                    .scaleEffect(0.72 + (0.48 * pointsBurstProgress))
                    .offset(y: -18 - (72 * pointsBurstProgress))
                    .opacity(1 - pointsBurstProgress)

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
            }
            .padding(26)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Selects which collectible to display for this pin. Prefers uncollected items
    /// so the user always sees something new. Falls back to any matching item if all
    /// have been collected. Uses `collectibleIDs` on the pin if available, otherwise
    /// falls back to the legacy `collectibleName` field.
    private func chooseCollectibleForCurrentPin() {
        let candidates = modelController.collectibles(for: pin)
        let notCollected = candidates.filter {
            !modelController.isCollectibleUnlocked(id: $0.id, name: $0.name)
        }
        activeCollectible = (notCollected.isEmpty ? candidates : notCollected).randomElement()
    }

    /// Recalculates the current flow state based on GPS proximity, surface detection,
    /// and collection status. Called on every location update and AR state change.
    /// The state machine guards are evaluated in priority order: no collectible →
    /// already collected → too far → teleport gate → surface detected → placed.
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
        } else if placementReadiness >= AppConstants.AR.readyToSpawnConfidenceThreshold {
            flowState = .readyToSpawn
        } else {
            flowState = .guiding
        }
    }

    /// Saves the captured collectible to SwiftData, plays the capture animation,
    /// switches to the collection tab, and dismisses after a short delay.
    private func handleCollectTapped() {
        flowState = .collecting
        playCaptureSuccessFeedback()
        runPointsBurstAnimation()

        if let activeCollectible {
            modelController.captureCollectible(collectible: activeCollectible, foundAtTitle: pin.title)
        } else {
            modelController.captureCollectible(
                collectibleName: collectibleName,
                rarity: collectibleRarity,
                foundAtTitle: pin.title,
                points: collectiblePoints
            )
        }

        collectFlowTask?.cancel()
        collectFlowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.collectRevealDelaySeconds * 1_000_000_000))
            flowState = .captured
            tabRouter.selectedTab = .collection
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.collectDismissDelaySeconds * 1_000_000_000))
            dismiss()
        }
    }

    private func runPointsBurstAnimation() {
        pointsBurstProgress = 0
        withAnimation(.easeOut(duration: AppConstants.AR.pointsBurstAnimationSeconds)) {
            pointsBurstProgress = 1
        }
    }

    private func playCaptureSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
    @Binding var placementReadiness: Double

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
            secondHorizontalSurfaceDetected: $secondHorizontalSurfaceDetected,
            placementReadiness: $placementReadiness
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?
        private var collectibleAnchor: AnchorEntity?
        private var collectibleEntity: Entity?
        private var tapTargetEntity: ModelEntity?
        private var currentModelAssetName: String?
        private var loadCancellable: AnyCancellable?
        private var horizontalPlaneAnchorCount = 0
        private var isCollectAnimationRunning = false
        private var candidatePosition: SIMD3<Float>?
        private var candidateStableSince: CFTimeInterval?
        var didTapCollectible: (() -> Void)?

        private let collectibleEntityName = "ar.collectible.entity"

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
            secondHorizontalSurfaceDetected: Binding<Bool>,
            placementReadiness: Binding<Double>
        ) {
            self.arView = arView

            // Guard all binding writes — unconditional writes trigger SwiftUI re-renders,
            // which call updateUIView again, creating a tight loop with raycasting each iteration.
            let newSecondSurface = horizontalPlaneAnchorCount >= 2
            if secondHorizontalSurfaceDetected.wrappedValue != newSecondSurface {
                secondHorizontalSurfaceDetected.wrappedValue = newSecondSurface
            }

            if !canSpawnCollectible {
                removeCollectibleIfNeeded()
                resetPlacementCandidate()
                if surfaceDetected.wrappedValue { surfaceDetected.wrappedValue = false }
                if hasPlaced.wrappedValue { hasPlaced.wrappedValue = false }
                if placementReadiness.wrappedValue != 0 { placementReadiness.wrappedValue = 0 }
                return
            }

            // Keep the collectible anchored in world space once placed so it doesn't
            // drift with camera movement as `updateUIView` runs repeatedly.
            if collectibleAnchor != nil {
                if !surfaceDetected.wrappedValue { surfaceDetected.wrappedValue = true }
                let placed = collectibleEntity != nil
                if hasPlaced.wrappedValue != placed { hasPlaced.wrappedValue = placed }
                if placementReadiness.wrappedValue != 1 { placementReadiness.wrappedValue = 1 }
                return
            }

            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let raycastResults = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)

            if let result = raycastResults.first {
                if !surfaceDetected.wrappedValue { surfaceDetected.wrappedValue = true }
                let readiness = updatePlacementCandidate(using: result.worldTransform)
                if placementReadiness.wrappedValue != readiness {
                    placementReadiness.wrappedValue = readiness
                }

                if readiness >= 1 {
                    placeOrMoveCollectible(using: result.worldTransform, modelAssetName: modelAssetName)
                    let placed = collectibleEntity != nil
                    if hasPlaced.wrappedValue != placed { hasPlaced.wrappedValue = placed }
                } else if hasPlaced.wrappedValue {
                    hasPlaced.wrappedValue = false
                }
            } else if shouldForceSpawnWithoutSurface {
                // Teleport fallback path: place collectible in front of camera after timeout.
                if !surfaceDetected.wrappedValue { surfaceDetected.wrappedValue = true }
                if placementReadiness.wrappedValue != 1 { placementReadiness.wrappedValue = 1 }
                placeCollectibleInFrontOfCamera(modelAssetName: modelAssetName)
                let placed = collectibleEntity != nil
                if hasPlaced.wrappedValue != placed { hasPlaced.wrappedValue = placed }
            } else {
                resetPlacementCandidate()
                if surfaceDetected.wrappedValue { surfaceDetected.wrappedValue = false }
                if hasPlaced.wrappedValue { hasPlaced.wrappedValue = false }
                if placementReadiness.wrappedValue != 0 { placementReadiness.wrappedValue = 0 }
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
                // Thread-safety measure: ensure model completion handlers mutate @State on MainThread
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
                    self.installTapTarget(for: entity)

                    self.collectibleAnchor?.addChild(entity)
                    self.collectibleEntity = entity
                })
        }

        private func placeCollectibleInFrontOfCamera(modelAssetName: String) {
            guard let arView else { return }
            let cameraTransform = arView.cameraTransform.matrix
            let forward = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
            let fallbackPosition = cameraPosition + normalize(forward) * AppConstants.AR.forcedSpawnDistanceMeters

            var fallbackTransform = matrix_identity_float4x4
            fallbackTransform.columns.3 = SIMD4<Float>(fallbackPosition.x, fallbackPosition.y, fallbackPosition.z, 1)
            placeOrMoveCollectible(using: fallbackTransform, modelAssetName: modelAssetName)
        }

        private func installFallbackEntity() {
            let fallbackMesh = MeshResource.generateSphere(radius: AppConstants.AR.fallbackSphereRadius)
            let fallbackMaterial = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: false)
            let fallbackEntity = ModelEntity(mesh: fallbackMesh, materials: [fallbackMaterial])
            fallbackEntity.name = collectibleEntityName
            fallbackEntity.scale = SIMD3<Float>(repeating: 1.0)
            fallbackEntity.generateCollisionShapes(recursive: true)
            installTapTarget(for: fallbackEntity)
            collectibleAnchor?.addChild(fallbackEntity)
            collectibleEntity = fallbackEntity
        }

        private func installTapTarget(for entity: Entity) {
            tapTargetEntity?.removeFromParent()

            entity.components.set(InputTargetComponent())

            let tapTargetMesh = MeshResource.generateSphere(radius: AppConstants.AR.collectibleTapTargetRadius)
            let transparentMaterial = SimpleMaterial(
                color: UIColor.white.withAlphaComponent(0.001),
                roughness: 1.0,
                isMetallic: false
            )
            let tapTarget = ModelEntity(mesh: tapTargetMesh, materials: [transparentMaterial])
            tapTarget.name = collectibleEntityName
            tapTarget.generateCollisionShapes(recursive: true)
            tapTarget.components.set(InputTargetComponent())

            entity.addChild(tapTarget)
            tapTargetEntity = tapTarget
        }

        private func normalizedScale(for entity: Entity, targetMaxDimension: Float) -> SIMD3<Float> {
            let bounds = entity.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            let maxDimension = max(extents.x, max(extents.y, extents.z))
            guard maxDimension.isFinite, maxDimension > 0 else {
                return SIMD3<Float>(repeating: AppConstants.AR.fallbackUniformScale)
            }

            let uniformScale = (targetMaxDimension / maxDimension) * AppConstants.AR.collectibleVisualScaleMultiplier
            let clampedScale = min(max(uniformScale, AppConstants.AR.minScale), AppConstants.AR.maxScale)
            return SIMD3<Float>(repeating: clampedScale)
        }

        private func targetMaxDimension(for modelAssetName: String) -> Float {
            if let mapped = AppConstants.AR.ModelSizing.targetDimensionByModelAsset[modelAssetName] {
                return mapped
            }

            if modelAssetName.contains("toy_") {
                return AppConstants.AR.ModelSizing.smallTargetMaxDimension
            }

            if modelAssetName.contains("robot") || modelAssetName.contains("biplane") {
                return AppConstants.AR.ModelSizing.largeTargetMaxDimension
            }

            return AppConstants.AR.ModelSizing.defaultTargetMaxDimension
        }

        private func removeCollectibleIfNeeded() {
            collectibleEntity = nil
            tapTargetEntity = nil
            currentModelAssetName = nil
            loadCancellable?.cancel()
            loadCancellable = nil
            resetPlacementCandidate()

            if let collectibleAnchor {
                collectibleAnchor.removeFromParent()
                self.collectibleAnchor = nil
            }
        }

        private func updatePlacementCandidate(using worldTransform: simd_float4x4) -> Double {
            let translation = worldTransform.translation
            let newPosition = SIMD3<Float>(translation.x, translation.y, translation.z)
            let now = CACurrentMediaTime()

            if let candidatePosition {
                let drift = simd_distance(candidatePosition, newPosition)
                if drift <= AppConstants.AR.placementCandidateDriftToleranceMeters {
                    self.candidatePosition = (candidatePosition + newPosition) * 0.5
                } else {
                    self.candidatePosition = newPosition
                    candidateStableSince = now
                }
            } else {
                candidatePosition = newPosition
                candidateStableSince = now
            }

            let stableSince = candidateStableSince ?? now
            let elapsed = now - stableSince
            return min(max(elapsed / AppConstants.AR.stablePlacementHoldSeconds, 0), 1)
        }

        private func resetPlacementCandidate() {
            candidatePosition = nil
            candidateStableSince = nil
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
            playTapFeedback()

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

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.collectibleAnimationCompletionDelaySeconds * 1_000_000_000))
                guard let self else { return }
                collectibleEntity.removeFromParent()
                self.collectibleEntity = nil
                self.didTapCollectible?()
                self.isCollectAnimationRunning = false
            }
        }

        private func playTapFeedback() {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 0.95)
            AudioServicesPlaySystemSound(SystemSoundID(AppConstants.AR.collectTapSoundID))
        }
    }
}

private struct ScoutGuidanceBanner: View {
    enum Mode {
        case scan
        case holdSteady(progress: Double)
    }

    let mode: Mode
    let title: String
    let subtitle: String

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            switch mode {
            case .scan:
                HStack(spacing: 16) {
                    ScoutPennant(icon: "sparkles", delay: 0.0)
                    BouncingArrow(delay: 0.08)
                    BouncingArrow(delay: 0.16)
                    BouncingArrow(delay: 0.24)
                    ScoutPennant(icon: "flag.fill", delay: 0.12)
                }
            case .holdSteady(let progress):
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 12)
                        .frame(width: 104, height: 104)

                    Circle()
                        .trim(from: 0, to: max(progress, 0.08))
                        .stroke(
                            AngularGradient(
                                colors: [Color("UMDGold"), Color.white, Color("UMDRed")],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 104, height: 104)

                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color("UMDGold"))
                            .offset(y: -66)
                            .rotationEffect(.degrees(Double(index) * 90))
                    }

                    Image(systemName: "scope")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .scaleEffect(pulse ? 1.04 : 0.96)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.68), Color(red: 0.33, green: 0.07, blue: 0.08).opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct BouncingArrow: View {
    let delay: Double
    @State private var offsetY: CGFloat = -4

    var body: some View {
        Image(systemName: "chevron.down.circle.fill")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color("UMDGold"))
            .shadow(color: Color("UMDGold").opacity(0.35), radius: 6, x: 0, y: 4)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(delay)) {
                    offsetY = 6
                }
            }
    }
}

private struct ScoutPennant: View {
    let icon: String
    let delay: Double
    @State private var rotate = -7.0

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white.opacity(0.92))
            .rotationEffect(.degrees(rotate))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(delay)) {
                    rotate = 7
                }
            }
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
