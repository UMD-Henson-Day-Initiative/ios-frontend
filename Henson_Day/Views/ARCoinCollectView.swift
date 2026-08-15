//  ARCoinCollectView.swift
//  Henson_Day
//
//  Full-screen AR flow for collecting an event's coin: every detected
//  horizontal plane gets a translucent overlay; once one has been stable for
//  a moment it auto-confirms and a gold coin spawns on it. Tapping the coin
//  submits a collect request to the backend (which re-validates proximity
//  server-side) and awards points on success.

import SwiftUI
import RealityKit
import ARKit
import Combine
import AudioToolbox
import UIKit
import CoreHaptics
import CoreLocation

struct ARCoinCollectView: View {
    enum FlowState: Equatable {
        case searching
        case confirming
        case placed
        case collecting
        case captured(pointsAwarded: Int)
        case failed(message: String)
    }

    let event: EventItem
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: FlowState = .searching
    @State private var hasPlaced = false
    @State private var hasDetectedPlane = false
    @State private var didTapCollectible = false
    @State private var pointsBurstProgress: CGFloat = 1
    @State private var collectFlowTask: Task<Void, Never>?
    @State private var replaceToken = UUID()

    private var isCapturing: Bool {
        switch flowState {
        case .collecting, .captured: return true
        default: return false
        }
    }

    private var shouldShowGuidanceCard: Bool {
        switch flowState {
        case .searching, .confirming, .failed: return true
        case .placed, .collecting, .captured: return false
        }
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: !isCapturing,
                isCapturing: isCapturing,
                replaceToken: replaceToken,
                hasPlaced: $hasPlaced,
                hasDetectedPlane: $hasDetectedPlane,
                didTapCollectible: $didTapCollectible
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    Text(event.title)
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

                if shouldShowGuidanceCard {
                    overlayCard
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                } else if flowState == .placed {
                    replaceButton
                        .padding(.bottom, 24)
                }
            }

            if isCapturing {
                captureAnimationOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            recalculateFlow()
        }
        .onDisappear {
            collectFlowTask?.cancel()
        }
        .onChange(of: hasPlaced) { _, _ in recalculateFlow() }
        .onChange(of: hasDetectedPlane) { _, _ in recalculateFlow() }
        .onChange(of: didTapCollectible) { _, tapped in
            guard tapped, flowState == .placed else { return }
            handleCollectTapped()
        }
    }

    @ViewBuilder
    private var overlayCard: some View {
        switch flowState {
        case .searching:
            promptCard(title: event.title, subtitle: "Looking for a flat surface — pan your camera around the floor.")
        case .confirming:
            promptCard(title: event.title, subtitle: "Hold steady — locking onto a surface.")
        case .collecting:
            promptCard(title: "Collecting…", subtitle: "Confirming with the server.")
        case .captured(let points):
            promptCard(
                title: "You collected the coin! +\(points) pts",
                subtitle: "Total points: \(appSession.profile?.totalPoints ?? 0)."
            )
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Text("Couldn't collect")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    flowState = .searching
                    hasPlaced = false
                    hasDetectedPlane = false
                    replaceToken = UUID()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .placed:
            EmptyView()
        }
    }

    private var replaceButton: some View {
        Button(action: triggerReplace) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Re-Place")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Re-place the coin")
    }

    private func triggerReplace() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        replaceToken = UUID()
        hasPlaced = false
        hasDetectedPlane = false
        recalculateFlow()
    }

    private var captureAnimationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                if case .captured(let points) = flowState {
                    Text("+\(points)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(DS.Color.gold)
                        .shadow(color: DS.Color.gold.opacity(0.45), radius: 14, x: 0, y: 4)
                        .scaleEffect(0.72 + (0.48 * pointsBurstProgress))
                        .offset(y: -18 - (72 * pointsBurstProgress))
                        .opacity(1 - pointsBurstProgress)
                }

                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(DS.Color.gold)

                    Text(isFinalCaptured ? "Collected!" : "Collecting…")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(26)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var isFinalCaptured: Bool {
        if case .captured = flowState { return true }
        return false
    }

    private func recalculateFlow() {
        if isCapturing { return }
        if case .failed = flowState { return }
        if hasPlaced {
            flowState = .placed
            return
        }
        flowState = hasDetectedPlane ? .confirming : .searching
    }

    private func handleCollectTapped() {
        flowState = .collecting
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        collectFlowTask?.cancel()
        collectFlowTask = Task { @MainActor in
            let coordinate = locationManager.coordinate
                ?? CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)

            guard let result = await appSession.collectCoin(for: event, at: coordinate) else {
                flowState = .failed(message: appSession.errorMessage ?? "Something went wrong.")
                return
            }

            runPointsBurstAnimation()
            flowState = .captured(pointsAwarded: result.pointsAwarded)

            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.collectRevealDelaySeconds * 1_000_000_000))
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
    let replaceToken: UUID
    @Binding var hasPlaced: Bool
    @Binding var hasDetectedPlane: Bool
    @Binding var didTapCollectible: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        wireCoordinatorCallbacks(context.coordinator)
        context.coordinator.lastSeenReplaceToken = replaceToken
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        wireCoordinatorCallbacks(context.coordinator)
        context.coordinator.handleReplaceTokenIfChanged(replaceToken)
        context.coordinator.syncState(
            arView: uiView,
            canSpawnCollectible: canSpawnCollectible,
            isCapturing: isCapturing,
            hasPlaced: $hasPlaced,
            hasDetectedPlane: $hasDetectedPlane
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    private func wireCoordinatorCallbacks(_ coordinator: Coordinator) {
        coordinator.didTapCollectible = { didTapCollectible = true }
        coordinator.didConfirmPlacement = { hasPlaced = true }
        coordinator.didStartDetectingPlanes = { hasDetectedPlane = true }
        coordinator.didLoseAllPlanes = { hasDetectedPlane = false }
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?

        private var coinAnchor: AnchorEntity?
        private var coinEntity: ModelEntity?
        private var isCollectAnimationRunning = false
        private var hapticEngine: CHHapticEngine?

        private struct PlaneVisualization {
            let anchorEntity: AnchorEntity
            let modelEntity: ModelEntity
            let firstSeen: CFTimeInterval
        }
        private var planeVisualizations: [UUID: PlaneVisualization] = [:]
        private var confirmedPlaneID: UUID?

        private enum PlacementMode { case firstStable, viewportPrioritized }
        private var placementMode: PlacementMode = .firstStable
        private var excludedPlaneID: UUID?

        private let planeStableDuration: CFTimeInterval = 1.0
        private let minPlaneArea: Float = 0.1   // m²

        private let coinEntityName = "ar.coin.entity"

        var didTapCollectible: (() -> Void)?
        var didConfirmPlacement: (() -> Void)?
        var didStartDetectingPlanes: (() -> Void)?
        var didLoseAllPlanes: (() -> Void)?
        var lastSeenReplaceToken: UUID?

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.session.delegate = self

            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            if let wideFormat = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing {
                configuration.videoFormat = wideFormat
            }
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)
        }

        func syncState(
            arView: ARView,
            canSpawnCollectible: Bool,
            isCapturing: Bool,
            hasPlaced: Binding<Bool>,
            hasDetectedPlane: Binding<Bool>
        ) {
            self.arView = arView
            if isCapturing { return }

            if !canSpawnCollectible {
                removeAllPlaneVisualizations()
                removeCoin()
                if hasPlaced.wrappedValue { hasPlaced.wrappedValue = false }
                if hasDetectedPlane.wrappedValue { hasDetectedPlane.wrappedValue = false }
                return
            }

            if coinAnchor != nil {
                if !hasPlaced.wrappedValue { hasPlaced.wrappedValue = true }
                prunePlaneVisualizationsToConfirmed()
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
            let rotation = simd_quatf(angle: plane.planeExtent.rotationOnYAxis, axis: SIMD3<Float>(0, 1, 0))
            return Transform(scale: .one, rotation: rotation, translation: center)
        }

        private func worldCorners(of plane: ARPlaneAnchor) -> [SIMD3<Float>] {
            let halfW = plane.planeExtent.width / 2
            let halfD = plane.planeExtent.height / 2
            let localOffsets: [SIMD3<Float>] = [
                SIMD3<Float>(-halfW, 0,  halfD),
                SIMD3<Float>( halfW, 0,  halfD),
                SIMD3<Float>( halfW, 0, -halfD),
                SIMD3<Float>(-halfW, 0, -halfD)
            ]
            let yRot = simd_quatf(angle: plane.planeExtent.rotationOnYAxis, axis: SIMD3<Float>(0, 1, 0))
            return localOffsets.map { offset in
                let local = plane.center + yRot.act(offset)
                let world4 = plane.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
                return SIMD3<Float>(world4.x, world4.y, world4.z)
            }
        }

        private func viewportProminenceScore(for plane: ARPlaneAnchor, in arView: ARView) -> Float? {
            var projected: [CGPoint] = []
            projected.reserveCapacity(4)
            for corner in worldCorners(of: plane) {
                guard let p = arView.project(corner) else { return nil }
                projected.append(p)
            }

            let centroid = CGPoint(
                x: (projected[0].x + projected[1].x + projected[2].x + projected[3].x) / 4,
                y: (projected[0].y + projected[1].y + projected[2].y + projected[3].y) / 4
            )

            var signedArea: CGFloat = 0
            for i in 0..<4 {
                let a = projected[i]
                let b = projected[(i + 1) % 4]
                signedArea += a.x * b.y - b.x * a.y
            }
            let area = Float(abs(signedArea) / 2)

            let bounds = arView.bounds
            let screenCenter = CGPoint(x: bounds.midX, y: bounds.midY)
            let dx = centroid.x - screenCenter.x
            let dy = centroid.y - screenCenter.y
            let distance = Float(sqrt(dx * dx + dy * dy))
            let halfDiagonal = Float(max(bounds.width, bounds.height) / 2)
            let normalizedDistance = halfDiagonal > 0 ? distance / halfDiagonal : 0

            return area / (1 + 2 * normalizedDistance)
        }

        private func makePlaneEntity(for plane: ARPlaneAnchor) -> ModelEntity {
            let mesh = MeshResource.generatePlane(width: plane.planeExtent.width, depth: plane.planeExtent.height)
            let material = translucentMaterial(color: .white, alpha: 0.3)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.transform = localTransform(for: plane)
            return entity
        }

        private func addPlaneVisualization(for plane: ARPlaneAnchor) {
            guard confirmedPlaneID == nil else { return }
            guard let arView, planeVisualizations[plane.identifier] == nil else { return }
            let wasEmpty = planeVisualizations.isEmpty
            let anchorEntity = AnchorEntity(.anchor(identifier: plane.identifier))
            let modelEntity = makePlaneEntity(for: plane)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
            planeVisualizations[plane.identifier] = PlaneVisualization(
                anchorEntity: anchorEntity,
                modelEntity: modelEntity,
                firstSeen: CACurrentMediaTime()
            )
            if wasEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.didStartDetectingPlanes?()
                }
            }
        }

        private func updatePlaneVisualization(for plane: ARPlaneAnchor) {
            if let confirmedPlaneID, plane.identifier != confirmedPlaneID {
                return
            }
            guard let viz = planeVisualizations[plane.identifier] else {
                addPlaneVisualization(for: plane)
                return
            }
            guard plane.identifier != confirmedPlaneID else { return }
            viz.modelEntity.model?.mesh = MeshResource.generatePlane(width: plane.planeExtent.width, depth: plane.planeExtent.height)
            viz.modelEntity.transform = localTransform(for: plane)
        }

        private func removePlaneVisualization(for id: UUID) {
            guard let viz = planeVisualizations.removeValue(forKey: id) else { return }
            viz.anchorEntity.removeFromParent()
            if confirmedPlaneID == id && coinAnchor == nil {
                confirmedPlaneID = nil
            }
            if planeVisualizations.isEmpty && coinAnchor == nil {
                DispatchQueue.main.async { [weak self] in
                    self?.didLoseAllPlanes?()
                }
            }
        }

        private func removeAllPlaneVisualizations() {
            for (_, viz) in planeVisualizations {
                viz.anchorEntity.removeFromParent()
            }
            planeVisualizations.removeAll()
            confirmedPlaneID = nil
        }

        private func prunePlaneVisualizationsToConfirmed() {
            guard let confirmedPlaneID else { return }
            let strayIDs = planeVisualizations.keys.filter { $0 != confirmedPlaneID }
            for id in strayIDs {
                if let viz = planeVisualizations.removeValue(forKey: id) {
                    viz.anchorEntity.removeFromParent()
                }
            }
        }

        // MARK: - Re-Place

        func handleReplaceTokenIfChanged(_ token: UUID) {
            guard lastSeenReplaceToken != token else { return }
            lastSeenReplaceToken = token
            resetPlacement()
        }

        private func resetPlacement() {
            excludedPlaneID = confirmedPlaneID
            placementMode = .viewportPrioritized
            removeCoin()
            removeAllPlaneVisualizations()
        }

        // MARK: - ARSessionDelegate

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard confirmedPlaneID == nil else {
                prunePlaneVisualizationsToConfirmed()
                return
            }
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal else { continue }
                addPlaneVisualization(for: plane)
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard confirmedPlaneID == nil else {
                prunePlaneVisualizationsToConfirmed()
                return
            }
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal else { continue }
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
            let now = CACurrentMediaTime()

            var currentPlanes: [UUID: ARPlaneAnchor] = [:]
            for anchor in frame.anchors {
                if let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal {
                    currentPlanes[plane.identifier] = plane
                }
            }

            let stableCandidates = planeVisualizations
                .compactMap { (id, viz) -> (ARPlaneAnchor, PlaneVisualization)? in
                    guard let plane = currentPlanes[id] else { return nil }
                    let age = now - viz.firstSeen
                    let area = plane.planeExtent.width * plane.planeExtent.height
                    guard age >= planeStableDuration, area >= minPlaneArea else { return nil }
                    return (plane, viz)
                }

            let chosen: (ARPlaneAnchor, PlaneVisualization)?
            switch placementMode {
            case .firstStable:
                chosen = stableCandidates.min { $0.1.firstSeen < $1.1.firstSeen }
            case .viewportPrioritized:
                if let arView {
                    chosen = stableCandidates
                        .filter { $0.0.identifier != excludedPlaneID }
                        .compactMap { (plane, viz) -> (ARPlaneAnchor, PlaneVisualization, Float)? in
                            guard let score = viewportProminenceScore(for: plane, in: arView) else { return nil }
                            return (plane, viz, score)
                        }
                        .max { $0.2 < $1.2 }
                        .map { ($0.0, $0.1) }
                } else {
                    chosen = nil
                }
            }

            if let (plane, viz) = chosen {
                confirmPlane(plane, viz: viz)
            }
        }

        // MARK: - Confirmation + Spawn

        private func confirmPlane(_ plane: ARPlaneAnchor, viz: PlaneVisualization) {
            confirmedPlaneID = plane.identifier

            viz.modelEntity.model?.materials = [translucentMaterial(color: .systemBlue, alpha: 0.45)]

            for (id, otherViz) in planeVisualizations where id != plane.identifier {
                otherViz.anchorEntity.removeFromParent()
            }
            planeVisualizations = [plane.identifier: viz]

            var localTranslation = matrix_identity_float4x4
            localTranslation.columns.3 = SIMD4<Float>(plane.center.x, 0, plane.center.z, 1)
            let world = matrix_multiply(plane.transform, localTranslation)
            placeCoin(at: world)

            placementMode = .firstStable
            excludedPlaneID = nil

            DispatchQueue.main.async { [weak self] in
                self?.didConfirmPlacement?()
            }
        }

        // MARK: - Coin Placement

        private func placeCoin(at worldTransform: simd_float4x4) {
            guard let arView, coinAnchor == nil else { return }

            let translation = worldTransform.translation
            let anchor = AnchorEntity(world: SIMD3<Float>(translation.x, translation.y, translation.z))
            arView.scene.addAnchor(anchor)
            coinAnchor = anchor

            let mesh = MeshResource.generateCylinder(
                height: AppConstants.AR.coinThicknessMeters,
                radius: AppConstants.AR.coinRadiusMeters
            )
            var material = SimpleMaterial()
            material.color = .init(tint: UIColor(DS.Color.gold), texture: nil)
            material.metallic = .init(floatLiteral: 1.0)
            material.roughness = .init(floatLiteral: 0.25)

            let coin = ModelEntity(mesh: mesh, materials: [material])
            coin.name = coinEntityName
            coin.generateCollisionShapes(recursive: true)
            coin.components.set(InputTargetComponent())

            let tapMesh = MeshResource.generateSphere(radius: AppConstants.AR.coinTapTargetRadiusMeters)
            let transparentMaterial = SimpleMaterial(color: UIColor.white.withAlphaComponent(0.001), roughness: 1.0, isMetallic: false)
            let tapTarget = ModelEntity(mesh: tapMesh, materials: [transparentMaterial])
            tapTarget.name = coinEntityName
            tapTarget.generateCollisionShapes(recursive: true)
            tapTarget.components.set(InputTargetComponent())
            coin.addChild(tapTarget)

            anchor.addChild(coin)
            coinEntity = coin

            playPlacementPulse()
        }

        private func removeCoin() {
            coinEntity = nil
            coinAnchor?.removeFromParent()
            coinAnchor = nil
            confirmedPlaneID = nil
        }

        // Smooth ~0.5s swell — a wave that crests then fades, not a tap.
        // Falls back to .success notification on simulator / non-haptic devices.
        private func playPlacementPulse() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
            do {
                if hapticEngine == nil {
                    let engine = try CHHapticEngine()
                    engine.isAutoShutdownEnabled = true
                    engine.resetHandler = { [weak engine] in
                        try? engine?.start()
                    }
                    hapticEngine = engine
                }
                try hapticEngine?.start()

                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 0.5)
                let intensityCurve = CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0.0, value: 0.0),
                        .init(relativeTime: 0.08, value: 1.0),
                        .init(relativeTime: 0.5, value: 0.0)
                    ],
                    relativeTime: 0
                )
                let pattern = try CHHapticPattern(events: [event], parameterCurves: [intensityCurve])
                let player = try hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            let location = recognizer.location(in: arView)
            guard let hitEntity = arView.entity(at: location) else { return }

            let tappedCoin = sequence(first: hitEntity, next: { $0.parent })
                .contains(where: { $0.name == coinEntityName })

            if tappedCoin {
                animateCoinTowardCameraAndCollect()
            }
        }

        private func animateCoinTowardCameraAndCollect() {
            guard !isCollectAnimationRunning else { return }
            guard let arView, let coinEntity else {
                didTapCollectible?()
                return
            }

            isCollectAnimationRunning = true
            playTapFeedback()
            removeAllPlaneVisualizations()

            let cameraMatrix = arView.cameraTransform.matrix
            let cameraPosition = SIMD3<Float>(cameraMatrix.columns.3.x, cameraMatrix.columns.3.y, cameraMatrix.columns.3.z)
            let forward = normalize(SIMD3<Float>(-cameraMatrix.columns.2.x, -cameraMatrix.columns.2.y, -cameraMatrix.columns.2.z))
            let up = normalize(SIMD3<Float>(cameraMatrix.columns.1.x, cameraMatrix.columns.1.y, cameraMatrix.columns.1.z))

            let targetPosition = cameraPosition + (forward * 0.18) - (up * 0.06)
            let currentScale = coinEntity.scale(relativeTo: nil)
            let targetScale = currentScale * SIMD3<Float>(repeating: 0.05)
            let targetTransform = Transform(
                scale: targetScale,
                rotation: coinEntity.orientation(relativeTo: nil),
                translation: targetPosition
            )

            coinEntity.move(to: targetTransform, relativeTo: nil, duration: 0.45, timingFunction: .easeInOut)

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.collectibleAnimationCompletionDelaySeconds * 1_000_000_000))
                guard let self else { return }
                coinEntity.removeFromParent()
                self.coinEntity = nil
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
