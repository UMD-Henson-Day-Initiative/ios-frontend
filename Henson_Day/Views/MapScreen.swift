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
import UIKit

struct MapScreen: View {
    private let isInTestingMode = AppConstants.Debug.isMapTeleportTestingEnabled

    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var cameraPermission: CameraPermissionManager
    @EnvironmentObject private var locationManager: LocationPermissionManager

    @State private var selectedPinID: UUID?
    @State private var isDetailPresented = false
    @State private var arPin: PinEntity?
    @State private var teleportPreloadCancellable: AnyCancellable?
    @State private var arLaunchTask: Task<Void, Never>?
    @StateObject private var proximityMonitor = ProximityMonitor()
    @State private var destinationPin: PinEntity?
    @State private var hasCelebratedBattleReady = false

    private var distanceToDestination: CLLocationDistance? {
        guard let pin = destinationPin else { return nil }
        return straightLineDistance(
            from: locationManager.effectiveCoordinate,
            to: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        )
    }

    private var liveDestinationPin: PinEntity? {
        guard let pin = destinationPin else { return nil }
        return modelController.pins.first(where: { $0.id == pin.id })
    }

    private var collectedCollectibleNames: Set<String> {
        Set(modelController.collectionItemsForCurrentUser().map(\.collectibleName))
    }

    private var collectedPinIDs: Set<UUID> {
        Set(
            modelController.pins.compactMap { pin in
                let pinCollectibles = modelController.collectibles(for: pin)
                return pinCollectibles.contains(where: {
                    modelController.isCollectibleUnlocked(id: $0.id, name: $0.name) || collectedCollectibleNames.contains($0.name)
                }) ? pin.id : nil
            }
        )
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
                mapView
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topStatusStrip
                    Spacer()
                }

                if !isDetailPresented,
                   let nearbyPin = proximityMonitor.nearbyPin,
                   let distance = proximityMonitor.distanceToNearbyPin,
                   let collectibleName = proximityMonitor.nearbyCollectibleName,
                   let rarity = proximityMonitor.nearbyCollectibleRarity,
                   let tier = proximityMonitor.tier {
                    ProximityAlertBanner(
                        pin: nearbyPin,
                        distance: distance,
                        collectibleName: collectibleName,
                        rarity: rarity,
                        tier: tier,
                        onViewAR: { launchARExperience(for: nearbyPin) },
                        onDismiss: { proximityMonitor.dismiss(pin: nearbyPin) }
                    )
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: proximityMonitor.nearbyPin?.id)
                    .animation(.easeInOut(duration: 0.25), value: proximityMonitor.tier)
                }

                if let selectedPin, isDetailPresented {
                    let hasEventDetails = modelController.scheduleEventID(matchingPinTitle: selectedPin.title) != nil

                    PinDetailBottomSheet(
                        detail: detailForPin(selectedPin),
                        pinCoordinate: CLLocationCoordinate2D(
                            latitude: selectedPin.latitude,
                            longitude: selectedPin.longitude
                        ),
                        userLocation: locationManager.effectiveCoordinate,
                        isPresented: Binding(
                            get: { isDetailPresented },
                            set: { newValue in
                                isDetailPresented = newValue
                                if !newValue {
                                    selectedPinID = nil
                                }
                            }
                        ),
                        onPrimaryAction: {
                            handlePrimaryAction(for: selectedPin)
                        },
                        onDetails: hasEventDetails ? {
                            openEventDetails(for: selectedPin)
                        } : nil,
                        onSetDestination: {
                            toggleDestination(selectedPin)
                        },
                        isCurrentDestination: destinationPin?.id == selectedPin.id
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $arPin, onDismiss: {
            finishARLaunchCleanup()
        }) { pin in
            ARCollectibleExperienceView(pin: pin)
                .environmentObject(modelController)
                .environmentObject(tabRouter)
                .environmentObject(locationManager)
        }
        .onAppear {
            modelController.refreshPublishedData()
            cameraPermission.requestIfNeeded()
            locationManager.requestWhenInUseAuthorizationIfNeeded()
            proximityMonitor.startMonitoring(locationManager: locationManager, modelController: modelController)
        }
        .onChange(of: destinationPin?.id) { _, _ in
            hasCelebratedBattleReady = false
        }
        .onChange(of: distanceToDestination) { _, newDistance in
            guard let d = newDistance else {
                hasCelebratedBattleReady = false
                return
            }
            if d > AppConstants.AR.collectibleProximityMeters {
                hasCelebratedBattleReady = false
            } else if !hasCelebratedBattleReady {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                hasCelebratedBattleReady = true
            }
        }
        .onDisappear {
            arLaunchTask?.cancel()
            teleportPreloadCancellable?.cancel()
        }
    }

    private var mapView: some View {
        MapView(pins: modelController.pins, collectedPinIDs: collectedPinIDs) { pin in
            selectedPinID = pin.id
            isDetailPresented = true
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
                if let pin = liveDestinationPin {
                    DestinationTrackerPill(
                        pin: pin,
                        distanceMeters: distanceToDestination,
                        onClear: { destinationPin = nil }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: liveDestinationPin?.id)


            if isInTestingMode {
                HStack {
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

    private func detailForPin(_ pin: PinEntity) -> MapPinDetail {
        let parsed = parseSubtitle(pin.subtitle)
        let collectible = modelController.preferredCollectible(for: pin)
        let availability = pin.availabilityState()

        return MapPinDetail(
            id: pin.id.uuidString,
            pinType: pin.pinType,
            availability: availability,
            title: pin.title,
            dayLabel: parsed.day,
            timeRange: parsed.time,
            locationName: parsed.location ?? pin.title,
            description: pin.pinDescription,
            collectibleName: collectible?.name ?? pin.collectibleName,
            collectibleRarity: collectible?.rarity ?? pin.collectibleRarity,
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
        guard modelController.isPinCurrentlyAvailable(pin) else { return }

        switch pin.pinType {
        case .event:
            if pin.hasARCollectible { launchARExperience(for: pin) }
        case .collectible:
            launchARExperience(for: pin)
        case .battle:
            launchARExperience(for: pin)
        case .homebase:
            tabRouter.selectedTab = .collection
        case .site, .concert:
            break
        }
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
            modelController.collectibles(for: pin).contains {
                $0.name == "Stadium Stomper" || $0.id == "c1"
            }
        }

        guard let targetPin else {
            return
        }

        let targetCoordinate = CLLocationCoordinate2D(
            latitude: targetPin.latitude,
            longitude: targetPin.longitude
        )
        locationManager.setTestingCoordinate(targetCoordinate)

        let modelAssetName = modelAssetNameForPin(targetPin) ?? "robot"

        arLaunchTask?.cancel()
        teleportPreloadCancellable?.cancel()

        // Preload before launching AR so model decode doesn't block initial collectible screen.
        teleportPreloadCancellable = Entity.loadModelAsync(named: modelAssetName)
            // Thread-safety measure: ensure model completion handlers dispatch to MainThread
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in
                teleportPreloadCancellable = nil
            }, receiveValue: { _ in })

        launchARExperience(for: targetPin)
    }

    private func modelAssetNameForPin(_ pin: PinEntity) -> String? {
        return modelController.preferredCollectible(for: pin)?.modelFileName
    }

    private func launchARExperience(for pin: PinEntity) {
        arLaunchTask?.cancel()
        arLaunchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.AR.teleportLaunchDelaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            arPin = pin
        }
    }

    private func finishARLaunchCleanup() {
        arLaunchTask?.cancel()
        teleportPreloadCancellable?.cancel()
        teleportPreloadCancellable = nil
    }

    private func toggleDestination(_ pin: PinEntity) {
        if destinationPin?.id == pin.id {
            destinationPin = nil
        } else {
            destinationPin = pin
        }
    }
}

#Preview {
    MapScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
        .environmentObject(CameraPermissionManager())
        .environmentObject(LocationPermissionManager())
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
