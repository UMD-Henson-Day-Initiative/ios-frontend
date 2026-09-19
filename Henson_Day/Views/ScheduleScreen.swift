//  ScheduleScreen.swift
//  Henson_Day
//
//  Lists every scheduled event for a selected day, with its time and location.
//  A horizontal day scroller (only showing dates that actually have events)
//  lets the user jump between days; it defaults to today when today has
//  events, otherwise the nearest upcoming day. Backed entirely by
//  AppSession.events (fetched from GET /events).

import CoreLocation
import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedDay: Date?
    @State private var collectingEventID: String?

    private var days: [Date] {
        let calendar = Calendar.current
        let uniqueDays = Set(appSession.events.map { calendar.startOfDay(for: $0.startTime) })
        return uniqueDays.sorted()
    }

    private var eventsForSelectedDay: [EventItem] {
        guard let selectedDay else { return [] }
        let calendar = Calendar.current
        return appSession.events
            .filter { calendar.isDate($0.startTime, inSameDayAs: selectedDay) }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScreenHeaderBanner(title: "Schedule")

                    AlternatingDotsDivider()

                    if appSession.isLoadingEvents && appSession.events.isEmpty {
                        Spacer()
                        ProgressView("Loading schedule…")
                        Spacer()
                    } else if appSession.events.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No events yet",
                            systemImage: "calendar",
                            description: Text("Check back once the schedule is published.")
                        )
                        Spacer()
                    } else {
                        daySelector

                        ScrollView {
                            VStack(alignment: .leading, spacing: DS.Spacing.card) {
                                if let selectedDay {
                                    Text(dayHeading(for: selectedDay))
                                        .font(DS.Typography.title1)
                                        .foregroundStyle(DS.Color.campusNight)
                                        .padding(.horizontal, DS.Spacing.screenH)
                                }

                                VStack(spacing: DS.Spacing.card) {
                                    ForEach(Array(eventsForSelectedDay.enumerated()), id: \.element.id) { index, event in
                                        TimelineRow(
                                            time: startTime(for: event),
                                            isLast: index == eventsForSelectedDay.count - 1
                                        ) {
                                            if event.isVirtual {
                                                ScheduleEventRow(
                                                    event: event,
                                                    isCollecting: collectingEventID == event.id,
                                                    onCollect: event.collected ? nil : { collectVirtualEvent(event) }
                                                )
                                            } else {
                                                Button {
                                                    tabRouter.focusedEventID = event.id
                                                    tabRouter.selectedTab = .map
                                                } label: {
                                                    ScheduleEventRow(event: event)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.screenH)

                                AlternatingDotsDivider()
                            }
                            .padding(.top, DS.Spacing.card)
                            .padding(.bottom, DS.Spacing.section)
                        }
                        .refreshable {
                            await appSession.loadEvents()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            if appSession.events.isEmpty {
                await appSession.loadEvents()
            }
            updateSelectedDayIfNeeded()
        }
        .onChange(of: appSession.events.count) { _, _ in
            updateSelectedDayIfNeeded()
        }
    }

    /// Virtual events have no location to point a map pin or an AR camera at,
    /// so there's no map/AR flow to collect them through — this collects
    /// directly from the schedule row instead. The backend doesn't apply a
    /// proximity check for virtual events, so any coordinate (or none) works.
    private func collectVirtualEvent(_ event: EventItem) {
        guard collectingEventID == nil else { return }
        collectingEventID = event.id
        Task {
            _ = await appSession.collectCoin(
                for: event,
                at: locationManager.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
            collectingEventID = nil
        }
    }

    private func updateSelectedDayIfNeeded() {
        guard selectedDay == nil || !days.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDay!) }) else { return }
        selectedDay = days.closestToToday()
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    ScheduleDayPill(
                        day: day,
                        isSelected: selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedDay = day
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            .padding(.vertical, 12)
        }
    }

    private func dayHeading(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day)
    }

    private func startTime(for event: EventItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startTime)
    }
}

/// Leading vertical-timeline rail: a time label, a dot, and a connecting
/// line down to the next event (omitted after the last one).
private struct TimelineRow<Content: View>: View {
    let time: String
    let isLast: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(time)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.neutral)
                    .fixedSize()

                ZStack(alignment: .top) {
                    if !isLast {
                        Rectangle()
                            .fill(DS.Color.gold.opacity(0.35))
                            .frame(width: 2)
                            .padding(.top, 12)
                    }
                    Circle()
                        .fill(DS.Color.heroGradient)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 50)

            content()
        }
    }
}

private struct ScheduleDayPill: View {
    let day: Date
    let isSelected: Bool
    let action: () -> Void

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: day)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.5)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : DS.Color.campusNight)
            .frame(width: 52, height: 56)
            .background {
                if isSelected {
                    DS.Color.heroGradient
                } else {
                    DS.Color.surfaceElevated
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.clear : DS.Color.gold.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: isSelected ? DS.Color.primary.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleEventRow: View {
    let event: EventItem
    var isCollecting: Bool = false
    var onCollect: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.card) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)

                HStack(spacing: 6) {
                    Image(systemName: event.isVirtual ? "globe" : "mappin")
                        .font(.caption)
                    Text(event.locationName)
                    if event.isVirtual {
                        Text("VIRTUAL")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(DS.Color.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Color.primaryTint)
                            .clipShape(Capsule())
                    }
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                VStack(spacing: 0) {
                    Text("+\(event.points)")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(DS.Color.campusNight)
                    Text("pts")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Color.campusNight.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.Color.goldGradient)
                .clipShape(Capsule())

                if event.collected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Color.statusCompleted)
                        .padding(.top, 2)
                } else if let onCollect {
                    Button(action: onCollect) {
                        if isCollecting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(height: 20)
                        } else {
                            Text("Collect")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DS.Color.heroGradient)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isCollecting)
                    .padding(.top, 2)
                }
            }
        }
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

#Preview {
    ScheduleScreen()
        .environmentObject(AppSession(authManager: AuthManager()))
        .environmentObject(TabRouter())
        .environmentObject(LocationManager())
}
