//  ARCollectibleExperienceView.swift
//  Henson_Day
//
//  File Description: This file defines the ARCollectibleExperienceView, which manages the full
//  AR collectible experience for a given pin. It handles proximity detection, surface scanning,
//  collectible spawning, tap-to-collect interactions, and capture animations. It also defines
//  ARPlacementView, a UIViewRepresentable that bridges RealityKit's ARView for placing and
//  animating 3D collectible models in the real world.
//

import SwiftUI

struct ARCaptureScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modelController: ModelController

    let collectibleId: String

    @State private var captured = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            ARCanvasView()   // your RealityView-based AR scene
                .ignoresSafeArea()

            VStack {
                // top bar, mode toggles, etc.
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding()

                Spacer()

                if !captured {
                    Button {
                        captured = true

                        if let collectible = modelController.collectibleCatalog.first(where: { $0.id == collectibleId }) {
                            modelController.captureCollectible(
                                collectibleName: collectible.name,
                                rarity: collectible.rarity,
                                foundAtTitle: collectible.location,
                                points: collectible.points
                            )
                        }

                        dismissTask?.cancel()
                        dismissTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.captureDismissDelaySeconds * 1_000_000_000))
                            dismiss()
                        }
                    } label: {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.6), lineWidth: 6)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }

            if captured {
                Color.black.opacity(0.7).ignoresSafeArea()
                Text("Captured!") // replace with full success UI
                    .font(.title)
                    .foregroundStyle(.black)
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
}



