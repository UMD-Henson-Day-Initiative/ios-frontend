//  MapScreen.swift
//  Henson_Day
//
//  Primary map hub: a day selector plus an Apple Maps view showing every
//  event's location for that day. Tapping a pin opens a detail sheet with a
//  Navigate button and a distance-gated Collect button that launches the AR
//  coin-collect flow.

import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var cameraPermission: CameraPermissionManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedDay: Date?
    @State private var selectedEventID: String?
    @State private var isDetailPresented = false
    @State private var arEvent: EventItem?
    @State private var focusCoordinate: CLLocationCoordinate2D?

    private var days: [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(appSession.events.map { calendar.startOfDay(for: $0.startTime) })
        return uniqueDays.sorted()
    }

    private var eventsForSelectedDay: [EventItem] {
        guard let selectedDay else { return appSession.events }
        let calendar = Calendar.current
        return appSession.events.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDay) }
    }

    private var selectedEvent: EventItem? {
        appSession.events.first(where: { $0.id == selectedEventID })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapView(events: eventsForSelectedDay, focusCoordinate: focusCoordinate) { event in
                    selectedEventID = event.id
                    isDetailPresented = true
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    if !days.isEmpty {
                        daySelector
                    }
                    Spacer()
                }

                if let selectedEvent, isDetailPresented {
                    PinDetailBottomSheet(
                        event: selectedEvent,
                        userLocation: locationManager.coordinate,
                        isPresented: Binding(
                            get: { isDetailPresented },
                            set: { newValue in
                                isDetailPresented = newValue
                                if !newValue { selectedEventID = nil }
                            }
                        ),
                        onCollect: {
                            arEvent = selectedEvent
                        }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $arEvent) { event in
            ARCoinCollectView(event: event)
                .environmentObject(appSession)
                .environmentObject(locationManager)
        }
        .onAppear {
            cameraPermission.requestIfNeeded()
            locationManager.requestWhenInUseAuthorizationIfNeeded()
            if selectedDay == nil {
                selectedDay = days.first
            }
            if appSession.events.isEmpty {
                Task { await appSession.loadEvents() }
            }
            focusOnEvent(withID: tabRouter.focusedEventID)
        }
        .onChange(of: appSession.events.count) { _, _ in
            if selectedDay == nil {
                selectedDay = days.first
            }
        }
        .onChange(of: tabRouter.focusedEventID) { _, newValue in
            focusOnEvent(withID: newValue)
        }
    }

    private func focusOnEvent(withID eventID: String?) {
        guard let eventID, let event = appSession.events.first(where: { $0.id == eventID }) else { return }

        selectedDay = Calendar.current.startOfDay(for: event.startTime)
        selectedEventID = event.id
        isDetailPresented = true
        focusCoordinate = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        tabRouter.focusedEventID = nil
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    DayPill(
                        day: day,
                        isSelected: selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

private struct DayPill: View {
    let day: Date
    let isSelected: Bool
    let action: () -> Void

    private var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: day)
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : DS.Color.campusNight)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? DS.Color.primary : DS.Color.surfaceElevated)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    MapScreen()
        .environmentObject(AppSession(authManager: AuthManager()))
        .environmentObject(TabRouter())
        .environmentObject(CameraPermissionManager())
        .environmentObject(LocationManager())
}
