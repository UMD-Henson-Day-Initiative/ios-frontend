//
//  ScheduleScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// ScheduleScreen.swift

import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: Int = 1

    var dayEvents: [Event] {
        appState.events.filter { $0.day == selectedDay }
    }

    var recommendedEvents: [Event] {
        appState.events.filter { $0.type == .rare || $0.type == .homebase }.prefix(3).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Day selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                FilterChip(
                                    label: "Day \(day)",
                                    isSelected: day == selectedDay
                                ) {
                                    selectedDay = day
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    // Recommended section (e.g. only for Day 1)
                    if selectedDay == 1 && !recommendedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(Color("UMDRed"))
                                Text("Recommended for You")
                                    .font(.headline)
                            }

                            VStack(spacing: 8) {
                                ForEach(recommendedEvents) { event in
                                    NavigationLink {
                                        EventDetailScreen(eventId: event.id)
                                    } label: {
                                        RecommendedEventCard(event: event)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Timeline for the day
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day \(selectedDay) Schedule")
                            .font(.headline)
                            .padding(.horizontal)

                        if dayEvents.isEmpty {
                            VStack(spacing: 8) {
                                Text("📅")
                                    .font(.largeTitle)
                                Text("No events scheduled")
                                    .font(.headline)
                                Text("Check back later for Day \(selectedDay) events.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(dayEvents) { event in
                                    NavigationLink {
                                        EventDetailScreen(eventId: event.id)
                                    } label: {
                                        TimelineEventRow(event: event)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Event Schedule")
        }
    }
}

struct RecommendedEventCard: View {
    @EnvironmentObject var appState: AppState
    let event: Event

    var collectible: Collectible? {
        guard let id = event.collectibleId else { return nil }
        return appState.collectibles.first { $0.id == id }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let c = collectible {
                Text(c.emoji)
                    .font(.largeTitle)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("UMDGold").opacity(0.25))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(event.time)
                        .font(.caption)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(event.location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [Color("UMDRed").opacity(0.05), Color("UMDGold").opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("UMDRed").opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct TimelineEventRow: View {
    @EnvironmentObject var appState: AppState
    let event: Event

    var collectible: Collectible? {
        guard let id = event.collectibleId else { return nil }
        return appState.collectibles.first { $0.id == id }
    }

    var typeColor: Color {
        switch event.type {
        case .homebase: return Color("UMDRed")
        case .rare: return Color("UMDGold")
        case .common: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: event.type == .homebase ? "house.fill" :
                        event.type == .rare ? "star.fill" :
                        "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(typeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(event.time)
                        .font(.caption)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(event.location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Text(event.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let c = collectible {
                Text(c.emoji)
                    .font(.title2)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 2)
    }
}

#Preview {
    ScheduleScreen()
}
