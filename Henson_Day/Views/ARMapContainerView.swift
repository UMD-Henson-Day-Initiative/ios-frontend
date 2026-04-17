//  ARMapContainerView.swift
//  Henson_Day
//
//  File Description: This file defines the ARMapContainerView, which manages the dual-view
//  layout that allows users to toggle between a full-screen AR camera view and a map view.
//  It handles camera and location permission requests on appear, renders a floating overlay
//  of whichever view is secondary, and provides a profile navigation button. It also defines
//  CameraPermissionPlaceholderView, shown when camera access has been denied or restricted.
//
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

struct ARMapContainerView: View {
    @Binding var isARPrimary: Bool

    @EnvironmentObject private var cameraPermission: CameraPermissionManager
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @EnvironmentObject private var worldAnchorManager: WorldAnchorManager

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                primaryContent
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        profileButton
                        Spacer()
                        overlayToggle(size: geometry.size)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    Spacer()
                }
            }
            .onAppear {
                cameraPermission.requestIfNeeded()
                locationManager.requestWhenInUseAuthorizationIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var primaryContent: some View {
        if isARPrimary {
            largeARView
        } else {
            MiniMapView(locationManager: locationManager)
        }
    }

    private var largeARView: some View {
        Group {
            if cameraPermission.isDeniedOrRestricted {
                CameraPermissionPlaceholderView()
            } else {
                ARCameraView(
                    isCameraAuthorized: cameraPermission.isAuthorized,
                    worldAnchorManager: worldAnchorManager
                )
            }
        }
    }

    private var profileButton: some View {
        NavigationLink {
            ProfileScreen()
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.55))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .accessibilityLabel("Open profile")
    }

    private func overlayToggle(size: CGSize) -> some View {
        let overlayWidth = min(max(size.width * 0.36, 132), 190)
        let overlayHeight = overlayWidth * 1.32

        return Group {
            if isARPrimary {
                MiniMapView(locationManager: locationManager)
            } else {
                largeARView
            }
        }
        .frame(width: overlayWidth, height: overlayHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: AppConstants.Map.primarySwapAnimationSeconds)) {
                isARPrimary.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Swap primary view")
    }
}

struct CameraPermissionPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 10) {
                Image(systemName: "camera.slash")
                    .font(.title)
                    .foregroundStyle(.white)
                Text("Camera access is disabled.")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Enable Camera permission to use the AR view.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}
