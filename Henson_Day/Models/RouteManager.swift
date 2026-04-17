//
//  RouteManager.swift
//  HensonDayInitiative
//
//  Created by Havish on 3/6/26.
//

import Foundation
import MapKit
import Combine

// NOTE: @MainActor is acceptable here. MKDirections.calculate() is async and
// properly suspends without blocking the main thread. All @Published properties
// drive UI, so main-actor isolation simplifies state updates.
@MainActor
class RouteManager: ObservableObject {
    @Published var route: MKRoute?
    @Published var currentStepIndex: Int = 0
    @Published var distanceToNextStep: CLLocationDistance = 0
    @Published var isNavigating: Bool = false
    @Published var routeError: UserFacingErrorState?

    func clearRouteError() {
        routeError = nil
    }

    var currentInstruction: String {
        guard let route, currentStepIndex < route.steps.count else {
            return ""
        }
        return route.steps[currentStepIndex].instructions
    }
    
    var currentStepDistance: CLLocationDistance {
        guard let route, currentStepIndex < route.steps.count else {
            return 0
        }
        return route.steps[currentStepIndex].distance
    }
    
    var totalDistance: CLLocationDistance {
        route?.distance ?? 0
    }
    
    var totalTime: TimeInterval {
        route?.expectedTravelTime ?? 0
    }
    
    func fetchRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        
        do {
            let result = try await MKDirections(request: request).calculate()
            self.route = result.routes.first
            self.currentStepIndex = 0
            self.isNavigating = true
        } catch {
            routeError = UserFacingErrorState(
                title: "Directions unavailable",
                message: "Couldn't calculate walking directions. Check your connection and try again."
            )
        }
    }
    
    func updateProgress(userLocation: CLLocation) {
        guard let route, isNavigating else { return }
        
        let steps = route.steps
        guard currentStepIndex < steps.count else {
            isNavigating = false
            return
        }
        
        let currentStep = steps[currentStepIndex]
        let stepEndCoordinate = currentStep.polyline.coordinate
        let stepEndLocation = CLLocation(latitude: stepEndCoordinate.latitude, longitude: stepEndCoordinate.longitude)
        
        distanceToNextStep = userLocation.distance(from: stepEndLocation)
        
        // Advance to next step when within stepAdvanceDistanceMeters
        if distanceToNextStep < AppConstants.Route.stepAdvanceDistanceMeters && currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        }

        // Check if arrived at destination
        if currentStepIndex == steps.count - 1 && distanceToNextStep < AppConstants.Route.arrivalDistanceMeters {
            isNavigating = false
        }
    }
    
    func cancelNavigation() {
        route = nil
        currentStepIndex = 0
        isNavigating = false
    }
}
