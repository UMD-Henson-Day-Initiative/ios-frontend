//  ScheduleScreen.swift
//  Henson_Day
//
//  Lists every scheduled event for a selected day, with its time and location.
//  A horizontal day scroller (only showing dates that actually have events)
//  lets the user jump between days; it defaults to today when today has
//  events, otherwise the nearest upcoming day. Backed entirely by
//  AppSession.events (fetched from GET /events).

import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var selectedDay: Date?

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
                                    ForEach(eventsForSelectedDay) { event in
                                        Button {
                                            tabRouter.focusedEventID = event.id
                                            tabRouter.selectedTab = .map
                                        } label: {
                                            ScheduleEventRow(event: event)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.screenH)
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

    private func updateSelectedDayIfNeeded() {
        guard selectedDay == nil || !days.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDay!) }) else { return }
        selectedDay = defaultDay
    }

    /// Today if it has events, otherwise the nearest upcoming day, otherwise the most recent past day.
    private var defaultDay: Date? {
        guard !days.isEmpty else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        if let match = days.first(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            return match
        }
        if let upcoming = days.first(where: { $0 > today }) {
            return upcoming
        }
        return days.last
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

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        guard let endTime = event.endTime else {
            return formatter.string(from: event.startTime)
        }
        return "\(formatter.string(from: event.startTime)) – \(formatter.string(from: endTime))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.card) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeRangeText)
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)

                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.caption)
                    Text(event.locationName)
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
}
