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

struct MapScreen: View {
    @EnvironmentObject private var modelController: ModelController

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.9869, longitude: -76.9426),
        span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)
    )
    @State private var selectedPinID: UUID?
    @State private var isDetailPresented = false
    @State private var arPin: PinEntity?
    @State private var showLeaderboard = false
    @State private var showCollection = false

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
                    floatingActions
                }

                if let selectedPin, isDetailPresented {
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
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Henson Day Map")
                        .font(.headline)
                }
            }
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
        }
        .onAppear {
            modelController.refreshPublishedData()
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
        VStack(spacing: 8) {
            HStack {
                Text(dayTimeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
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
}

#Preview {
    MapScreen()
        .environmentObject(ModelController())
}
