//
//  MapScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// MapScreen.swift

import SwiftUI
import MapKit
import CoreLocation
import RealityKit
import Combine

struct MapScreen: View {
    // Toggle this to hide all location-teleport testing controls in camera mode.
    private let isInTestingMode = AppConstants.Debug.isMapTeleportTestingEnabled

    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var region = MKCoordinateRegion(
        center: CampusConfigProvider.campusCenter,
        span: AppConstants.Map.mapRegionSpan
    )
    @State private var selectedPinID: UUID?
    @State private var isDetailPresented = false
    @State private var arPin: PinEntity?
    @State private var showLeaderboard = false
    @State private var showCollection = false
    @State private var isCameraPrimary = false
    @State private var suppressMiniCameraFeed = false
    @State private var isPreparingTeleportLaunch = false
    @State private var teleportPreloadCancellable: AnyCancellable?
    @State private var teleportLaunchTask: Task<Void, Never>?
    @State private var teleportResetTask: Task<Void, Never>?

    @StateObject private var cameraPermission = CameraPermissionManager()
    @StateObject private var worldAnchorManager = WorldAnchorManager()
    @StateObject private var locationManager = LocationPermissionManager()

    private var collectedCatalogItems: [DatabaseCollectible] {
        let collectedNames = Set(modelController.collectionItemsForCurrentUser().map(\.collectibleName))
        return modelController.collectibleCatalog.filter { collectedNames.contains($0.name) }
    }

    private var selectedPin: PinEntity? {
        modelController.pins.first(where: { $0.id == selectedPinID })
    }

    private var dayTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Day 1 • \(formatter.string(from: .now))"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                primaryPanel
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topStatusStrip
                    Spacer()
                    floatingActions
                }

                miniSwapPanel

                if let selectedPin, isDetailPresented {
                    let hasEventDetails = modelController.scheduleEventID(matchingPinTitle: selectedPin.title) != nil

                    PinDetailBottomSheet(
                        detail: detailForPin(selectedPin),
                        isPresented: Binding(
                            get: { isDetailPresented },
                            set: { newValue in
                                isDetailPresented = newValue
                                if !newValue {
                                    selectedPinID = nil
                                }
                            }
                        ),
                        onNavigate: {
                            openInMaps(selectedPin)
                        },
                        onPrimaryAction: {
                            handlePrimaryAction(for: selectedPin)
                        },
                        onDetails: hasEventDetails ? {
                            openEventDetails(for: selectedPin)
                        } : nil
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showLeaderboard) {
            MinimalLeaderboardSheet(
                players: modelController.leaderboardUsers,
                localUserID: modelController.currentUser?.id
            )
        }
        .sheet(isPresented: $showCollection) {
            MyCollectionSheet(items: modelController.collectionItemsForCurrentUser())
        }
        .fullScreenCover(item: $arPin) { pin in
            ARCollectibleExperienceView(pin: pin)
                .environmentObject(modelController)
                .environmentObject(tabRouter)
                .environmentObject(locationManager)
        }
        .onAppear {
            modelController.refreshPublishedData()
            cameraPermission.requestIfNeeded()
            locationManager.requestWhenInUseAuthorizationIfNeeded()
            region.center = modelController.campusCenter
        }
        .onDisappear {
            teleportLaunchTask?.cancel()
            teleportResetTask?.cancel()
            teleportPreloadCancellable?.cancel()
        }
    }

    @ViewBuilder
    private var primaryPanel: some View {
        if isCameraPrimary {
            if cameraPermission.isDeniedOrRestricted {
                CameraPermissionPlaceholderView()
            } else {
                ARCameraView(
                    isCameraAuthorized: cameraPermission.isAuthorized,
                    worldAnchorManager: worldAnchorManager,
                    availableCollectibles: collectedCatalogItems,
                    isPaused: arPin != nil || isPreparingTeleportLaunch,
                    showPlacementControls: true
                )
            }
        } else {
            mapView
        }
    }

    private var mapView: some View {
        Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true, annotationItems: modelController.pins) { pin in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                Button {
                    selectedPinID = pin.id
                    isDetailPresented = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(pin.pinType.mapMarkerColor)
                            .frame(width: 22, height: 22)

                        if selectedPinID == pin.id {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var topStatusStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Text(dayTimeLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                Spacer()
            }

            HStack {
                if let user = modelController.currentUser {
                    Circle()
                        .fill(Color(hex: user.avatarColorHex))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: user.avatarType.symbolName)
                                .foregroundStyle(.white)
                        )
                        .onTapGesture {
                            tabRouter.selectedTab = .profile
                        }
                }
                Spacer()
            }

            HStack {
                Spacer()
                Text("\(modelController.currentUser?.totalPoints ?? 0) pts • \(modelController.currentUser?.collectedCount ?? 0) collectibles")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: AppConstants.Map.primarySwapAnimationSeconds)) {
                        isCameraPrimary.toggle()
                    }
                } label: {
                    Label(isCameraPrimary ? "Map" : "Camera", systemImage: isCameraPrimary ? "map.fill" : "camera.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            if isCameraPrimary && isInTestingMode {
                HStack {
                    // TESTING ONLY: This button spoofs the user's location to a not-yet-collected collectible pin.
                    Button("Teleport to a collectible location") {
                        teleportToUncollectedCollectiblePin()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var miniSwapPanel: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    Group {
                        if isCameraPrimary {
                            mapView
                        } else {
                            if suppressMiniCameraFeed {
                                miniCameraPlaceholder
                            } else if cameraPermission.isDeniedOrRestricted {
                                CameraPermissionPlaceholderView()
                            } else {
                                ARCameraView(
                                    isCameraAuthorized: cameraPermission.isAuthorized,
                                    worldAnchorManager: worldAnchorManager,
                                    availableCollectibles: collectedCatalogItems,
                                    isPaused: arPin != nil || isPreparingTeleportLaunch,
                                    showPlacementControls: false
                                )
                            }
                        }
                    }
                    .frame(width: min(170, geometry.size.width * 0.4), height: 205)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.85), lineWidth: 1)
                    )
                    .overlay {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: AppConstants.Map.primarySwapAnimationSeconds)) {
                                    isCameraPrimary.toggle()
                                }
                            }
                    }
                    .shadow(radius: 6)
                }
                .padding(.top, 30)
                .padding(.horizontal, 12)

                Spacer()
            }
        }
        .allowsHitTesting(true)
    }

    private var miniCameraPlaceholder: some View {
        ZStack {
            Color.black.opacity(0.75)
            VStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Camera")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var floatingActions: some View {
        HStack(spacing: 12) {
            Button {
                showLeaderboard = true
            } label: {
                Label("Leaderboard", systemImage: "list.number")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            Button {
                showCollection = true
            } label: {
                Label("My Collection", systemImage: "cube.box")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(.bottom, 18)
    }

    private func detailForPin(_ pin: PinEntity) -> MapPinDetail {
        let parsed = parseSubtitle(pin.subtitle)

        return MapPinDetail(
            id: pin.id.uuidString,
            pinType: pin.pinType,
            title: pin.title,
            dayLabel: parsed.day,
            timeRange: parsed.time,
            locationName: parsed.location ?? pin.title,
            description: pin.pinDescription,
            collectibleName: pin.collectibleName,
            collectibleRarity: pin.collectibleRarity,
            hasARCollectible: pin.hasARCollectible
        )
    }

    private func parseSubtitle(_ subtitle: String?) -> (day: String?, time: String?, location: String?) {
        guard let subtitle else { return (nil, nil, nil) }
        let parts = subtitle.split(separator: "•").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let day = parts.indices.contains(0) ? parts[0] : nil
        let time = parts.indices.contains(1) ? parts[1] : nil
        let location = parts.indices.contains(2) ? parts[2] : nil
        return (day, time, location)
    }

    private func handlePrimaryAction(for pin: PinEntity) {
        switch pin.pinType {
        case .event:
            if pin.hasARCollectible { arPin = pin }
        case .collectible:
            arPin = pin
        case .battle:
            arPin = pin
        case .homebase:
            showCollection = true
        case .site, .concert:
            break
        }
    }

    private func openInMaps(_ pin: PinEntity) {
        let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pin.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func openEventDetails(for pin: PinEntity) {
        guard let eventID = modelController.scheduleEventID(matchingPinTitle: pin.title) else { return }
        isDetailPresented = false
        selectedPinID = nil
        tabRouter.focusedScheduleEventID = eventID
        tabRouter.selectedTab = .schedule
    }

    private func teleportToUncollectedCollectiblePin() {
        // Testing flow: always teleport to the Stadium Stomper pin and then
        // open the collectible experience after a short delay.
        let targetPin = modelController.pins.first { pin in
            if pin.collectibleName == "Stadium Stomper" { return true }

            let pinCollectibleIDs = Database.pins.first(where: { $0.title == pin.title })?.collectibleIDs ?? []
            return pinCollectibleIDs.contains("c1")
        }

        guard let targetPin else {
            return
        }

        let targetCoordinate = CLLocationCoordinate2D(
            latitude: targetPin.latitude,
            longitude: targetPin.longitude
        )
        locationManager.setTestingCoordinate(targetCoordinate)
        region.center = targetCoordinate

        // Temporarily suspend mini camera feed to avoid camera-session contention during AR launch.
        suppressMiniCameraFeed = true
        isPreparingTeleportLaunch = true

        let modelAssetName = modelAssetNameForPin(targetPin) ?? "robot"

        teleportLaunchTask?.cancel()
        teleportResetTask?.cancel()
        teleportPreloadCancellable?.cancel()

        // Preload before launching AR so model decode doesn't block initial collectible screen.
        teleportPreloadCancellable = Entity.loadModelAsync(named: modelAssetName)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                teleportPreloadCancellable = nil

                teleportLaunchTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.teleportLaunchDelaySeconds * 1_000_000_000))
                    arPin = targetPin
                }
            }, receiveValue: { _ in })

        teleportResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.teleportFallbackDelaySeconds * 1_000_000_000))
            suppressMiniCameraFeed = false
            isPreparingTeleportLaunch = false
        }
    }

    private func modelAssetNameForPin(_ pin: PinEntity) -> String? {
        let pinCollectibleIDs = Database.pins.first(where: { $0.title == pin.title })?.collectibleIDs ?? []

        if let byID = Database.collectibleCatalog.first(where: { pinCollectibleIDs.contains($0.id) }) {
            return byID.modelFileName
        }

        if let collectibleName = pin.collectibleName,
           let byName = Database.collectibleCatalog.first(where: { $0.name == collectibleName }) {
            return byName.modelFileName
        }

        return nil
    }
}

#Preview {
    MapScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}
