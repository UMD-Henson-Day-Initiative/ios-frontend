//  ARCanvasView.swift
//  Henson_Day
//
//  File Description: This file defines the ARCanvasView, a simple augmented reality view that
//  renders a metallic gray cube anchored to a detected horizontal surface in the real world.
//  It serves as a demo canvas for RealityKit content, using spatial tracking for camera alignment.
//

import SwiftUI
import RealityKit

struct ARCanvasView: View {
    var body: some View {
        RealityView { content in
            // Simple demo content: cube on a horizontal plane
            let model = Entity()

            let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
            let material = SimpleMaterial(
                color: .gray,
                roughness: 0.15,
                isMetallic: true
            )

            model.components.set(ModelComponent(mesh: mesh, materials: [material]))
            model.position = [0, 0.05, 0]

            let anchor = AnchorEntity(
                .plane(
                    .horizontal,
                    classification: .any,
                    minimumBounds: SIMD2<Float>(0.2, 0.2)
                )
            )
            anchor.addChild(model)

            content.add(anchor)
            content.camera = .spatialTracking
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ARCanvasView()
}

