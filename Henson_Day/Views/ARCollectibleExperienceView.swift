import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine

struct ARCollectibleExperienceView: View {
    enum FlowState {
        case tooFar
        case detectSurface
        case placed
        case alreadyCollected
        case collecting
        case captured
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

    // Per-pin configurable radius (meters). If a pin title is not listed, fallback radius is used.
    private let spawnRadiusByPinTitle: [String: CLLocationDistance] = [
        "Stadium Spirit Rally": 45,
        "McKeldin Time Capsule": 35,
        "Evening Concert": 40,
        "Quantum Courtyard Pop-Up": 30,
        "Finale Badge Sprint": 50
    ]
    private let defaultSpawnRadiusMeters: CLLocationDistance = 35
    private let collectiblePoints: Int = 50

    private var collectibleName: String {
        pin.collectibleName ?? pin.title
    }

    private var collectibleModelAssetName: String {
        // Maps each collectible to a USDZ model in /3DModels.
        switch collectibleName {
        case "Stadium Stomper":
            return "robot"
        case "Mall Muppet":
            return "toy_car"
        case "Soundwave Snare":
            return "hummingbird_anim"
        case "Quantum Smth":
            return "toy_biplane_realistic"
        case "Finale Flare":
            return "slide"
        default:
            return "robot"
        }
    }

    private var formattedDistance: String {
        guard let distanceMeters else { return "--" }
        return "\(Int(distanceMeters.rounded())) m"
    }

    private var spawnRadiusMeters: CLLocationDistance {
        spawnRadiusByPinTitle[pin.title] ?? defaultSpawnRadiusMeters
    }

    private var locationModeLabel: String {
        locationManager.testingOverrideCoordinate == nil ? "LIVE" : "TESTING OVERRIDE"
    }

    private var alreadyCollected: Bool {
        modelController.hasCollectedCollectible(named: collectibleName)
    }

    var body: some View {
        ZStack {
            ARPlacementView(
                canSpawnCollectible: isWithinSpawnRadius && !alreadyCollected,
                modelAssetName: collectibleModelAssetName,
                surfaceDetected: $surfaceDetected,
                hasPlaced: $hasPlaced,
                didTapCollectible: $didTapCollectible
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    // Top-left debug badge to show whether AR location uses live GPS or testing override.
                    Text(locationModeLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
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

                if isWithinSpawnRadius && !alreadyCollected {
                    Text("\(collectibleName) is nearby!")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                }

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
            // Evaluate proximity immediately so the correct AR state appears as soon as the screen opens.
            recalculateProximityAndFlow()
        }
        .onReceive(locationManager.$currentCoordinate.combineLatest(locationManager.$testingOverrideCoordinate)) { _ in
            // Re-check radius whenever GPS updates or when the test teleport override changes.
            recalculateProximityAndFlow()
        }
        .onChange(of: surfaceDetected) { _, _ in
            recalculateProximityAndFlow()
        }
        .onChange(of: hasPlaced) { _, _ in
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
        case .tooFar:
            promptCard(
                title: "Move closer to unlock this collectible",
                subtitle: "Current distance: \(formattedDistance). Get within \(Int(spawnRadiusMeters)) m of \(pin.title)."
            ) {
                EmptyView()
            }
        case .detectSurface:
            promptCard(title: "Look around for a horizontal surface", subtitle: "You are in range. The model appears when a floor/table surface is found.") {
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

    private func recalculateProximityAndFlow() {
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

        if hasPlaced {
            flowState = .placed
        } else {
            flowState = .detectSurface
        }
    }

    private func handleCollectTapped() {
        flowState = .collecting

        // Persist the capture after the tap on the model.
        modelController.captureCollectible(from: pin, points: collectiblePoints)

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
    let modelAssetName: String
    @Binding var surfaceDetected: Bool
    @Binding var hasPlaced: Bool
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
            modelAssetName: modelAssetName,
            surfaceDetected: $surfaceDetected,
            hasPlaced: $hasPlaced,
            didTapCollectible: $didTapCollectible
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
        var didTapCollectible: (() -> Void)?

        private let collectibleEntityName = "ar.collectible.entity"

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.session.delegate = self

            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            // Tap recognizer is used to detect when the user taps directly on the placed 3D collectible.
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)
        }

        func syncState(
            arView: ARView,
            canSpawnCollectible: Bool,
            modelAssetName: String,
            surfaceDetected: Binding<Bool>,
            hasPlaced: Binding<Bool>,
            didTapCollectible: Binding<Bool>
        ) {
            self.arView = arView
            _ = didTapCollectible

            if !canSpawnCollectible {
                removeCollectibleIfNeeded()
                surfaceDetected.wrappedValue = false
                hasPlaced.wrappedValue = false
                return
            }

            // Raycast from screen center so the model appears where the user is currently looking.
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            let raycastResults = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)

            if let result = raycastResults.first {
                surfaceDetected.wrappedValue = true
                placeOrMoveCollectible(using: result.worldTransform, modelAssetName: modelAssetName)
                hasPlaced.wrappedValue = collectibleEntity != nil
            } else {
                surfaceDetected.wrappedValue = false
                hasPlaced.wrappedValue = false
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            // Keep session delegate for future AR events; placement uses per-frame raycasts in syncState.
        }

        private func placeOrMoveCollectible(using worldTransform: simd_float4x4, modelAssetName: String) {
            guard let arView else { return }

            let translation = worldTransform.translation
            let targetPosition = SIMD3<Float>(translation.x, translation.y, translation.z)

            if collectibleAnchor == nil {
                let anchor = AnchorEntity(world: targetPosition)
                collectibleAnchor = anchor
                arView.scene.addAnchor(anchor)
            } else {
                collectibleAnchor?.position = targetPosition
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
                    entity.scale = SIMD3<Float>(repeating: 0.25)
                    entity.generateCollisionShapes(recursive: true)
                    entity.components.set(InputTargetComponent())

                    self.collectibleAnchor?.addChild(entity)
                    self.collectibleEntity = entity
                })
        }

        private func installFallbackEntity() {
            let fallbackMesh = MeshResource.generateSphere(radius: 0.12)
            let fallbackMaterial = SimpleMaterial(color: .systemRed, roughness: 0.3, isMetallic: false)
            let fallbackEntity = ModelEntity(mesh: fallbackMesh, materials: [fallbackMaterial])
            fallbackEntity.name = collectibleEntityName
            fallbackEntity.generateCollisionShapes(recursive: true)
            fallbackEntity.components.set(InputTargetComponent())
            collectibleAnchor?.addChild(fallbackEntity)
            collectibleEntity = fallbackEntity
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
                didTapCollectible?()
            }
        }
    }
}

private extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
