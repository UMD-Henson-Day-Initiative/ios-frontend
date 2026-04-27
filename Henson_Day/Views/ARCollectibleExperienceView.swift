import SwiftUI
import RealityKit
import ARKit
import Combine
import AudioToolbox
import UIKit

/// Full-screen AR experience for finding and collecting a muppet at a map pin.
///
/// Flow: every detected horizontal plane gets a translucent white overlay; once one
/// plane has been observed for `planeStableDuration` and exceeds `minPlaneArea`, it
/// auto-confirms (turns translucent blue) and the muppet spawns at its center.
struct ARCollectibleExperienceView: View {
    enum FlowState {
        case searching
        case confirming
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

    @State private var flowState: FlowState = .searching
    @State private var hasPlaced = false
    @State private var hasDetectedPlane = false
    @State private var didTapCollectible = false
    @State private var activeCollectible: DatabaseCollectible?
    @State private var pointsBurstProgress: CGFloat = 1
    @State private var collectFlowTask: Task<Void, Never>?

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

    private var alreadyCollected: Bool {
        if let activeCollectible {
            return modelController.isCollectibleUnlocked(id: activeCollectible.id, name: activeCollectible.name)
        }
        return modelController.hasCollectedCollectible(named: collectibleName)
    }

    private var canSpawnCollectible: Bool {
        activeCollectible != nil && !alreadyCollected
    }

    private var isCapturing: Bool {
        flowState == .collecting || flowState == .captured
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: canSpawnCollectible,
                isCapturing: isCapturing,
                modelAssetName: collectibleModelAssetName,
                hasPlaced: $hasPlaced,
                hasDetectedPlane: $hasDetectedPlane,
                didTapCollectible: $didTapCollectible
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    Text(collectibleName)
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.55))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

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

            if isCapturing {
                captureAnimationOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            chooseCollectibleForCurrentPin()
            recalculateFlow()
        }
        .onDisappear {
            collectFlowTask?.cancel()
        }
        .onChange(of: hasPlaced) { _, _ in
            recalculateFlow()
        }
        .onChange(of: hasDetectedPlane) { _, _ in
            recalculateFlow()
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
            )
        case .searching:
            promptCard(
                title: collectibleName,
                subtitle: "Looking for a flat surface — pan your camera around the floor."
            )
        case .confirming:
            promptCard(
                title: collectibleName,
                subtitle: "Hold steady — locking onto a surface."
            )
        case .placed:
            promptCard(title: collectibleName, subtitle: "Tap the 3D model to collect +\(collectiblePoints) points.")
        case .alreadyCollected:
            VStack(alignment: .leading, spacing: 10) {
                Text("Already collected")
                    .font(.headline)
                Text("You already captured \(collectibleName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Go to Gallery") {
                    tabRouter.selectedTab = .collection
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("UMDRed"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .collecting:
            promptCard(title: "Collecting \(collectibleName)...", subtitle: "Nice find. Finalizing your capture.")
        case .captured:
            promptCard(
                title: "You collected \(collectibleName)! +\(collectiblePoints) pts",
                subtitle: "Unlocked in the UMD Index. Total points: \(currentTotalPoints)."
            )
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

    private func chooseCollectibleForCurrentPin() {
        let candidates = modelController.collectibles(for: pin)
        let notCollected = candidates.filter {
            !modelController.isCollectibleUnlocked(id: $0.id, name: $0.name)
        }
        activeCollectible = (notCollected.isEmpty ? candidates : notCollected).randomElement()
    }

    private func recalculateFlow() {
        if isCapturing { return }

        guard activeCollectible != nil else {
            flowState = .noCollectiblesConfigured
            return
        }
        if alreadyCollected {
            flowState = .alreadyCollected
            return
        }
        if hasPlaced {
            flowState = .placed
            return
        }
        flowState = hasDetectedPlane ? .confirming : .searching
    }

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
}

struct ARPlacementView: UIViewRepresentable {
    let canSpawnCollectible: Bool
    let isCapturing: Bool
    let modelAssetName: String
    @Binding var hasPlaced: Bool
    @Binding var hasDetectedPlane: Bool
    @Binding var didTapCollectible: Bool

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
            isCapturing: isCapturing,
            modelAssetName: modelAssetName,
            hasPlaced: $hasPlaced,
            hasDetectedPlane: $hasDetectedPlane
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?

        private var collectibleAnchor: AnchorEntity?
        private var collectibleEntity: Entity?
        private var tapTargetEntity: ModelEntity?
        private var loadCancellable: AnyCancellable?
        private var isCollectAnimationRunning = false

        private struct PlaneVisualization {
            let anchorEntity: AnchorEntity
            let modelEntity: ModelEntity
            let firstSeen: CFTimeInterval
        }
        private var planeVisualizations: [UUID: PlaneVisualization] = [:]
        private var confirmedPlaneID: UUID?
        private var latestModelAssetName: String?

        private let planeStableDuration: CFTimeInterval = 1.0
        private let minPlaneArea: Float = 0.1   // m²

        private let collectibleEntityName = "ar.collectible.entity"

        var didTapCollectible: (() -> Void)?

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
            isCapturing: Bool,
            modelAssetName: String,
            hasPlaced: Binding<Bool>,
            hasDetectedPlane: Binding<Bool>
        ) {
            self.arView = arView
            latestModelAssetName = modelAssetName

            if isCapturing { return }

            if !canSpawnCollectible {
                removeAllPlaneVisualizations()
                removeCollectible()
                if hasPlaced.wrappedValue { hasPlaced.wrappedValue = false }
                if hasDetectedPlane.wrappedValue { hasDetectedPlane.wrappedValue = false }
                return
            }

            if collectibleAnchor != nil {
                if !hasPlaced.wrappedValue { hasPlaced.wrappedValue = true }
                return
            }

            let detected = !planeVisualizations.isEmpty
            if hasDetectedPlane.wrappedValue != detected {
                hasDetectedPlane.wrappedValue = detected
            }
        }

        // MARK: - Plane Visualization

        private func translucentMaterial(color: UIColor, alpha: CGFloat) -> SimpleMaterial {
            var m = SimpleMaterial()
            m.color = .init(tint: color.withAlphaComponent(alpha), texture: nil)
            m.roughness = 0.9
            m.metallic = 0.0
            return m
        }

        private func localTransform(for plane: ARPlaneAnchor) -> Transform {
            let center = SIMD3<Float>(plane.center.x, 0, plane.center.z)
            let rotation = simd_quatf(
                angle: plane.planeExtent.rotationOnYAxis,
                axis: SIMD3<Float>(0, 1, 0)
            )
            return Transform(scale: .one, rotation: rotation, translation: center)
        }

        private func makePlaneEntity(for plane: ARPlaneAnchor) -> ModelEntity {
            let mesh = MeshResource.generatePlane(
                width: plane.planeExtent.width,
                depth: plane.planeExtent.height
            )
            let material = translucentMaterial(color: .white, alpha: 0.3)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.transform = localTransform(for: plane)
            return entity
        }

        private func addPlaneVisualization(for plane: ARPlaneAnchor) {
            guard let arView, planeVisualizations[plane.identifier] == nil else { return }
            let anchorEntity = AnchorEntity(.anchor(identifier: plane.identifier))
            let modelEntity = makePlaneEntity(for: plane)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
            planeVisualizations[plane.identifier] = PlaneVisualization(
                anchorEntity: anchorEntity,
                modelEntity: modelEntity,
                firstSeen: CACurrentMediaTime()
            )
        }

        private func updatePlaneVisualization(for plane: ARPlaneAnchor) {
            guard let viz = planeVisualizations[plane.identifier] else {
                addPlaneVisualization(for: plane)
                return
            }
            guard plane.identifier != confirmedPlaneID else { return }
            viz.modelEntity.model?.mesh = MeshResource.generatePlane(
                width: plane.planeExtent.width,
                depth: plane.planeExtent.height
            )
            viz.modelEntity.transform = localTransform(for: plane)
        }

        private func removePlaneVisualization(for id: UUID) {
            guard let viz = planeVisualizations.removeValue(forKey: id) else { return }
            viz.anchorEntity.removeFromParent()
            if confirmedPlaneID == id { confirmedPlaneID = nil }
        }

        private func removeAllPlaneVisualizations() {
            for (_, viz) in planeVisualizations {
                viz.anchorEntity.removeFromParent()
            }
            planeVisualizations.removeAll()
            confirmedPlaneID = nil
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor,
                      plane.alignment == .horizontal else { continue }
                addPlaneVisualization(for: plane)
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor,
                      plane.alignment == .horizontal else { continue }
                updatePlaneVisualization(for: plane)
            }
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                removePlaneVisualization(for: plane.identifier)
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard confirmedPlaneID == nil else { return }
            guard latestModelAssetName != nil else { return }
            let now = CACurrentMediaTime()

            var currentPlanes: [UUID: ARPlaneAnchor] = [:]
            for anchor in frame.anchors {
                if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal {
                    currentPlanes[plane.identifier] = plane
                }
            }

            let candidate = planeVisualizations
                .compactMap { (id, viz) -> (ARPlaneAnchor, PlaneVisualization)? in
                    guard let plane = currentPlanes[id] else { return nil }
                    let age = now - viz.firstSeen
                    let area = plane.planeExtent.width * plane.planeExtent.height
                    guard age >= planeStableDuration, area >= minPlaneArea else { return nil }
                    return (plane, viz)
                }
                .min { $0.1.firstSeen < $1.1.firstSeen }

            if let (plane, viz) = candidate {
                confirmPlane(plane, viz: viz)
            }
        }

        // MARK: - Confirmation + Spawn

        private func confirmPlane(_ plane: ARPlaneAnchor, viz: PlaneVisualization) {
            guard let modelAssetName = latestModelAssetName else { return }
            confirmedPlaneID = plane.identifier

            viz.modelEntity.model?.materials = [translucentMaterial(color: .systemBlue, alpha: 0.45)]

            for (id, otherViz) in planeVisualizations where id != plane.identifier {
                otherViz.anchorEntity.removeFromParent()
            }
            planeVisualizations = [plane.identifier: viz]

            var localTranslation = matrix_identity_float4x4
            localTranslation.columns.3 = SIMD4<Float>(plane.center.x, 0, plane.center.z, 1)
            let world = matrix_multiply(plane.transform, localTranslation)
            placeCollectible(at: world, modelAssetName: modelAssetName)
        }

        // MARK: - Collectible Placement

        private func placeCollectible(at worldTransform: simd_float4x4, modelAssetName: String) {
            guard let arView, collectibleAnchor == nil else { return }

            let translation = worldTransform.translation
            let anchor = AnchorEntity(world: SIMD3<Float>(translation.x, translation.y, translation.z))
            arView.scene.addAnchor(anchor)
            collectibleAnchor = anchor

            loadCancellable = Entity.loadModelAsync(named: modelAssetName)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure = completion {
                        self.installFallbackEntity()
                    }
                }, receiveValue: { [weak self] entity in
                    guard let self else { return }
                    self.attachCollectible(entity: entity, modelAssetName: modelAssetName)
                })
        }

        private func attachCollectible(entity: Entity, modelAssetName: String) {
            entity.name = collectibleEntityName
            let targetDimension = targetMaxDimension(for: modelAssetName)
            entity.scale = normalizedScale(for: entity, targetMaxDimension: targetDimension)
            entity.position = SIMD3<Float>(0, 0, 0)
            entity.generateCollisionShapes(recursive: true)
            installTapTarget(for: entity)

            collectibleAnchor?.addChild(entity)
            collectibleEntity = entity
        }

        private func installFallbackEntity() {
            let fallbackMesh = MeshResource.generateSphere(radius: AppConstants.AR.fallbackSphereRadius)
            let fallbackMaterial = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: false)
            let fallbackEntity = ModelEntity(mesh: fallbackMesh, materials: [fallbackMaterial])
            fallbackEntity.name = collectibleEntityName
            fallbackEntity.position = SIMD3<Float>(0, 0, 0)
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

        private func removeCollectible() {
            collectibleEntity = nil
            tapTargetEntity = nil
            loadCancellable?.cancel()
            loadCancellable = nil

            collectibleAnchor?.removeFromParent()
            collectibleAnchor = nil
            confirmedPlaneID = nil
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
            removeAllPlaneVisualizations()

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

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
