import SwiftUI
import RealityKit
import ARKit

struct ARCollectibleExperienceView: View {
    enum FlowState {
        case detectSurface
        case readyToPlace
        case placed
        case captured
    }

    let pin: PinEntity
    @EnvironmentObject private var modelController: ModelController
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: FlowState = .detectSurface
    @State private var surfaceDetected = false
    @State private var hasPlaced = false
    @State private var placeTrigger = 0

    var body: some View {
        ZStack {
            ARPlacementView(
                surfaceDetected: $surfaceDetected,
                hasPlaced: $hasPlaced,
                placeTrigger: $placeTrigger
            )
            .ignoresSafeArea()

            VStack {
                HStack {
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
        }
        .onChange(of: surfaceDetected) { _, detected in
            if detected && flowState == .detectSurface {
                flowState = .readyToPlace
            }
        }
        .onChange(of: hasPlaced) { _, placed in
            if placed {
                flowState = .placed
            }
        }
    }

    @ViewBuilder
    private var overlayCard: some View {
        switch flowState {
        case .detectSurface:
            promptCard(title: "Move your phone to detect the ground", subtitle: "Scan the area slowly to find a surface.") {
                EmptyView()
            }
        case .readyToPlace:
            promptCard(title: "Surface found", subtitle: "Ghost preview is ready. Tap to place.") {
                Button("Tap to Place") {
                    placeTrigger += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("UMDRed"))
            }
        case .placed:
            promptCard(title: pin.collectibleName ?? pin.title, subtitle: "Collect this item for +50 pts") {
                Button("Capture") {
                    modelController.captureCollectible(from: pin, points: 50)
                    flowState = .captured
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("UMDRed"))
            }
        case .captured:
            promptCard(
                title: "You collected \(pin.collectibleName ?? pin.title)! +50 pts",
                subtitle: "Your collection and leaderboard score were updated offline."
            ) {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("UMDRed"))
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
    @Binding var surfaceDetected: Bool
    @Binding var hasPlaced: Bool
    @Binding var placeTrigger: Int

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        context.coordinator.lastPlaceTrigger = placeTrigger
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.syncState(
            arView: uiView,
            placeTrigger: placeTrigger,
            surfaceDetected: $surfaceDetected,
            hasPlaced: $hasPlaced
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?
        private var ghostAnchor: AnchorEntity?
        private var modelEntity: ModelEntity?
        var lastPlaceTrigger = 0

        func configure(_ arView: ARView) {
            self.arView = arView
            arView.session.delegate = self

            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            showGhostIfNeeded()
        }

        func syncState(
            arView: ARView,
            placeTrigger: Int,
            surfaceDetected: Binding<Bool>,
            hasPlaced: Binding<Bool>
        ) {
            self.arView = arView

            if placeTrigger != lastPlaceTrigger {
                placeModel()
                lastPlaceTrigger = placeTrigger
                hasPlaced.wrappedValue = true
            }

            if surfaceDetected.wrappedValue && ghostAnchor == nil {
                showGhostIfNeeded()
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            if anchors.contains(where: { $0 is ARPlaneAnchor }) {
                DispatchQueue.main.async {
                    self.showGhostIfNeeded()
                }
            }
        }

        private func showGhostIfNeeded() {
            guard ghostAnchor == nil, let arView else { return }

            let mesh = MeshResource.generateSphere(radius: 0.09)
            let material = SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.45), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            self.modelEntity = entity

            let anchor = AnchorEntity(world: [0, -0.1, -0.8])
            anchor.addChild(entity)
            ghostAnchor = anchor
            arView.scene.addAnchor(anchor)
        }

        private func placeModel() {
            guard let modelEntity else { return }
            modelEntity.model?.materials = [SimpleMaterial(color: .systemRed, roughness: 0.2, isMetallic: false)]
            modelEntity.scale = SIMD3<Float>(repeating: 1.15)
        }
    }
}
