import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    let pins: [PinEntity]
    let collectedPinIDs: Set<UUID>
    var onPinTapped: (PinEntity) -> Void = { _ in }

    static let minLat = AppConstants.Map.campusBoundsMinLat
    static let maxLat = AppConstants.Map.campusBoundsMaxLat
    static let minLon = AppConstants.Map.campusBoundsMinLon
    static let maxLon = AppConstants.Map.campusBoundsMaxLon

    static let umdCenter = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )

    static let campusBounds = MapCameraBounds(
        centerCoordinateBounds: MKCoordinateRegion(
            center: umdCenter,
            span: MKCoordinateSpan(
                latitudeDelta: maxLat - minLat,
                longitudeDelta: maxLon - minLon
            )
        ),
        minimumDistance: AppConstants.Map.cameraMinDistance,
        maximumDistance: AppConstants.Map.cameraMaxDistance
    )

    @StateObject private var locationManager = LocationManager()

    @State private var cameraDistance: Double = AppConstants.Map.defaultCameraDistance
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: umdCenter,
            distance: AppConstants.Map.defaultCameraDistance,
            heading: 0,
            pitch: AppConstants.Map.defaultCameraPitch
        )
    )
    @State private var isFollowingUser = true
    @State private var playerHeading: Double = 0
    @State private var selectedPinID: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, bounds: MapView.campusBounds) {
                // Player character
                if let location = locationManager.location {
                    Annotation("", coordinate: location.coordinate, anchor: .center) {
                        PlayerMarkerView(heading: playerHeading)
                    }
                }

                // Waypoint markers
                ForEach(pins) { pin in
                    let coord = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                    Annotation("", coordinate: coord, anchor: .bottom) {
                        WaypointMarkerView(
                            pin: pin,
                            isSelected: selectedPinID == pin.id,
                            isCollected: collectedPinIDs.contains(pin.id)
                        )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedPinID = selectedPinID == pin.id ? nil : pin.id
                                }
                                onPinTapped(pin)
                            }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic, pointsOfInterest: .including([
                .university, .library, .museum, .theater, .cafe, .restaurant, .park
            ])))
            .mapControls {
                MapCompass()
                    .mapControlVisibility(.hidden)
            }
            .ignoresSafeArea()
            .onChange(of: locationManager.location) { _, newLocation in
                guard let location = newLocation, isFollowingUser else { return }
                updateCamera(for: location, heading: playerHeading)
            }
            .onChange(of: locationManager.heading) { _, newHeading in
                guard let heading = newHeading else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    playerHeading = heading.trueHeading
                }
                if isFollowingUser, let location = locationManager.location {
                    updateCamera(for: location, heading: heading.trueHeading)
                }
            }
            .onMapCameraChange { context in
                if isFollowingUser {
                    cameraDistance = context.camera.distance
                    if let location = locationManager.location {
                        let camLat = context.camera.centerCoordinate.latitude
                        let camLon = context.camera.centerCoordinate.longitude
                        let latDiff = abs(camLat - location.coordinate.latitude)
                        let lonDiff = abs(camLon - location.coordinate.longitude)
                        if latDiff > AppConstants.Map.followLossThreshold || lonDiff > AppConstants.Map.followLossThreshold {
                            isFollowingUser = false
                        }
                    }
                }
            }

            // Recenter button — top left, below the avatar strip
            Button {
                cameraDistance = AppConstants.Map.defaultCameraDistance
                isFollowingUser = true
                if let location = locationManager.location {
                    let camera = MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: AppConstants.Map.defaultCameraDistance,
                        heading: playerHeading,
                        pitch: AppConstants.Map.defaultCameraPitch
                    )
                    withAnimation(.easeOut(duration: 0.4)) {
                        cameraPosition = .camera(camera)
                    }
                }
            } label: {
                Image(systemName: isFollowingUser ? "location.fill" : "location")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(isFollowingUser ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background {
                        if isFollowingUser {
                            Color.blue
                        } else {
                            Rectangle().fill(.ultraThinMaterial)
                        }
                    }
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .padding(.leading, 14)
            .padding(.top, 170)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            locationManager.requestAuthorization()
        }
    }

    private func updateCamera(for location: CLLocation, heading: Double = 0) {
        let camera = MapCamera(
            centerCoordinate: location.coordinate,
            distance: cameraDistance,
            heading: heading,
            pitch: AppConstants.Map.defaultCameraPitch
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .camera(camera)
        }
    }
}

// MARK: - Player Character Marker

struct PlayerMarkerView: View {
    let heading: Double

    var body: some View {
        ZStack {
            Triangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 16, height: 20)
                .offset(y: -22)
                .rotationEffect(.degrees(heading))

            Circle()
                .fill(Color.red)
                .frame(width: 28, height: 28)
                .overlay(
                    Text("T")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Waypoint Marker

struct WaypointMarkerView: View {
    let pin: PinEntity
    let isSelected: Bool
    let isCollected: Bool
    @State private var isPulsing = false
    @State private var appeared = false

    private var pinColor: Color { pin.pinType.mapMarkerColor }
    private var availability: PinAvailabilityState { pin.availabilityState() }
    private var markerOpacity: Double { availability.isActive ? 1.0 : 0.5 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Ground glow
                Ellipse()
                    .fill(pinColor.opacity(0.3))
                    .frame(width: 36, height: 12)
                    .blur(radius: 4)
                    .offset(y: 24)
                    .opacity(markerOpacity)

                // Pulse ring
                Circle()
                    .fill(pinColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.5)
                    .opacity(availability.isActive ? 1.0 : 0.0)

                // Outer ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinColor.opacity(0.8), pinColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: isSelected ? 42 : 38, height: isSelected ? 42 : 38)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                    .opacity(markerOpacity)

                // Inner face
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinColor.opacity(0.6), pinColor, pinColor.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 36 : 32, height: isSelected ? 36 : 32)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    center: .init(x: 0.35, y: 0.3),
                                    startRadius: 0,
                                    endRadius: 16
                                )
                            )
                    )
                    .overlay(
                        Image(systemName: pin.pinType.icon)
                            .font(.system(size: isSelected ? 16 : 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 2)
                    )

                if !availability.isActive {
                    Image(systemName: availability.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .offset(x: 16, y: -16)
                }

                if pin.hasARCollectible && isCollected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color("UMDGold"), .white)
                        .padding(4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color("UMDGold").opacity(0.7), lineWidth: 1)
                        )
                        .offset(x: -16, y: -16)
                }
            }
            .scaleEffect(appeared ? 1.0 : 0.3)
            .scaleEffect(isSelected ? 1.15 : 1.0)

            // Pin stem
            Triangle()
                .fill(pinColor)
                .frame(width: 12, height: 8)
                .rotationEffect(.degrees(180))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                .offset(y: -2)
                .opacity(markerOpacity)
        }
        .onAppear {
            if availability.isActive {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

#Preview(){
    MapView(pins: [], collectedPinIDs: [])
}
