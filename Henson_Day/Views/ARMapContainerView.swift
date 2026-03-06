import SwiftUI

struct ARMapContainerView: View {
    @Binding var isARPrimary: Bool

    @StateObject private var cameraPermission = CameraPermissionManager()
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var worldAnchorManager = WorldAnchorManager()

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
            withAnimation(.easeInOut(duration: 0.2)) {
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
