//  ScheduleScreen.swift
//  Henson_Day
//
//  Lists every scheduled event, grouped by day, with its time and location.
//  Backed entirely by AppSession.events (fetched from GET /events).

import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var tabRouter: TabRouter

    private var daySections: [(day: Date, events: [EventItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: appSession.events) { calendar.startOfDay(for: $0.startTime) }
        return grouped
            .map { (day: $0.key, events: $0.value.sorted { $0.startTime < $1.startTime }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                if appSession.isLoadingEvents && appSession.events.isEmpty {
                    ProgressView("Loading schedule…")
                } else if appSession.events.isEmpty {
                    ContentUnavailableView(
                        "No events yet",
                        systemImage: "calendar",
                        description: Text("Check back once the schedule is published.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.section) {
                            ForEach(daySections, id: \.day) { section in
                                VStack(alignment: .leading, spacing: DS.Spacing.card) {
                                    Text(dayHeading(for: section.day))
                                        .font(DS.Typography.title1)
                                        .foregroundStyle(DS.Color.campusNight)
                                        .padding(.horizontal, DS.Spacing.screenH)

                                    VStack(spacing: DS.Spacing.card) {
                                        ForEach(section.events) { event in
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
                            }
                        }
                        .padding(.top, DS.Spacing.section)
                        .padding(.bottom, DS.Spacing.section)
                    }
                    .refreshable {
                        await appSession.loadEvents()
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            if appSession.events.isEmpty {
                await appSession.loadEvents()
            }
        }
    }

    private func dayHeading(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day)
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

            VStack(spacing: 2) {
                Text("+\(event.points)")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.gold)
                Text("pts")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)

                if event.collected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Color.statusCompleted)
                        .padding(.top, 4)
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
