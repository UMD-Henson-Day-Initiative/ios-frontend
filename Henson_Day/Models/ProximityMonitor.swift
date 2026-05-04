import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class ProximityMonitor: ObservableObject {
    enum ProximityTier { case outer, inner }

    @Published private(set) var nearbyPin: PinEntity?
    @Published private(set) var distanceToNearbyPin: Double?
    @Published private(set) var nearbyCollectibleRarity: String?
    @Published private(set) var nearbyCollectibleName: String?
    @Published private(set) var tier: ProximityTier?

    private var locationManager: LocationPermissionManager?
    private var modelController: ModelController?
    private var cancellables = Set<AnyCancellable>()
    private var dismissedPinIDs = Set<UUID>()
    private var previousNearbyPinID: UUID?

    private let outerRadius: CLLocationDistance = AppConstants.AR.proximityNearRadiusMeters
    private let innerRadius: CLLocationDistance = AppConstants.AR.proximityRadiusMeters

    func startMonitoring(locationManager: LocationPermissionManager, modelController: ModelController) {
        guard cancellables.isEmpty else { return }
        self.locationManager = locationManager
        self.modelController = modelController

        locationManager.$currentCoordinate
            .combineLatest(locationManager.$testingOverrideCoordinate)
            .debounce(for: .milliseconds(AppConstants.AR.proximityDebounceMilliseconds), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.evaluate()
            }
            .store(in: &cancellables)
    }

    func dismiss(pin: PinEntity) {
        dismissedPinIDs.insert(pin.id)
        if nearbyPin?.id == pin.id {
            nearbyPin = nil
            distanceToNearbyPin = nil
            nearbyCollectibleRarity = nil
            nearbyCollectibleName = nil
            tier = nil
        }
    }

    private func evaluate() {
        guard let locationManager, let modelController else { return }
        guard let userCoordinate = locationManager.effectiveCoordinate else { return }

        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)

        let collectedNames = Set(modelController.collectionItemsForCurrentUser().map(\.collectibleName))

        // Clear dismissed pins that are now beyond radius
        let arPins = modelController.pins.filter {
            $0.hasARCollectible && modelController.isPinCurrentlyAvailable($0)
        }
        for dismissedID in dismissedPinIDs {
            if let pin = arPins.first(where: { $0.id == dismissedID }) {
                let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
                if userLocation.distance(from: pinLocation) > outerRadius {
                    dismissedPinIDs.remove(dismissedID)
                }
            }
        }

        // Find closest uncollected AR pin within radius
        var closestPin: PinEntity?
        var closestDistance: Double = .greatestFiniteMagnitude
        var closestCollectible: DatabaseCollectible?

        for pin in arPins {
            guard !dismissedPinIDs.contains(pin.id) else { continue }

            let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            let distance = userLocation.distance(from: pinLocation)
            guard distance <= outerRadius else { continue }

            // Resolve collectible for this pin
            let candidates = modelController.collectibles(for: pin)

            let uncollected = candidates.filter { !collectedNames.contains($0.name) }
            guard let collectible = uncollected.first else { continue }

            if distance < closestDistance {
                closestDistance = distance
                closestPin = pin
                closestCollectible = collectible
            }
        }

        let oldNearbyPinID = nearbyPin?.id

        if let closestPin, let collectible = closestCollectible {
            nearbyPin = closestPin
            distanceToNearbyPin = closestDistance
            nearbyCollectibleRarity = collectible.rarity
            nearbyCollectibleName = collectible.name
            tier = closestDistance <= innerRadius ? .inner : .outer

            // Haptic when transitioning from no nearby pin to a nearby pin
            if oldNearbyPinID == nil {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        } else {
            nearbyPin = nil
            distanceToNearbyPin = nil
            nearbyCollectibleRarity = nil
            nearbyCollectibleName = nil
            tier = nil
        }
    }
}
