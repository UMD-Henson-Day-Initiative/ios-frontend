//  ScheduleScreen.swift
//  Henson_Day
//
//  File Description: This file defines the ScheduleScreen view for the Henson Day
//  app. It displays the event schedule for each day of the program, allows
//  users to filter events by day, view event details in a full-screen
//  modal, and interact with events by opening their location on the map,
//  visiting the UMD website, or accessing collectibles in the collection.

import SwiftUI

// MARK: - Theme Colors (matches CollectiblesScreen CT palette)

private enum ST {
    static let hensRed         = Color(red: 0.85, green: 0.15, blue: 0.15)
    static let hensRedSoft     = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let hensYellow      = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let hensYellowSoft  = Color(red: 1.00, green: 0.93, blue: 0.55)
    static let hensCream       = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let hensWarm        = Color(red: 0.99, green: 0.94, blue: 0.82)
    static let hensMid         = Color(red: 0.97, green: 0.88, blue: 0.72)
    static let hensDimText     = Color(red: 0.65, green: 0.30, blue: 0.25)
    static let hensFadedText   = Color(red: 0.75, green: 0.45, blue: 0.35)
    static let hensBackground  = Color(red: 1.00, green: 1.00, blue: 1.00)
}

// MARK: - Schedule Screen

struct ScheduleScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.openURL) private var openURL
    @State private var viewingAddedOnly = false
    @State private var selectedDay: Int = 1
    @State private var selectedEvent: DatabaseEvent?

    private var daySections: [ScheduleEventSection] {
        modelController.groupedScheduleSections(forDay: selectedDay, addedOnly: viewingAddedOnly)
    }

    private var days: [Int] {
        let available = Set(modelController.scheduleEvents.map(\.dayNumber))
        return Array(available).sorted()
    }

    private var totalVisibleEvents: Int {
        let allEvents = modelController.scheduleEvents
        if viewingAddedOnly {
            return allEvents.filter { modelController.addedScheduleEventIDs.contains($0.id) }.count
        }
        return allEvents.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ST.hensBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Festive banner header
                    ScheduleFestiveBannerView(
                        selectedDay: selectedDay,
                        totalEvents: totalVisibleEvents,
                        viewingAddedOnly: viewingAddedOnly
                    )
                    .ignoresSafeArea(edges: .top)

                    // Scope toggle
                    ScheduleScopeToggleView(viewingAddedOnly: $viewingAddedOnly)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(ST.hensBackground)

                    // Day pill strip
                    ScheduleDayPillStrip(
                        days: days.isEmpty ? Array(1...7) : days,
                        selectedDay: selectedDay,
                        events: modelController.scheduleEvents
                    ) { day in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedDay = day
                        }
                    }
                    .background(ST.hensBackground)

                    Divider()
                        .background(ST.hensYellow)

                    // Timeline
                    ScheduleTimelineEventList(
                        sections: daySections,
                        onTap: { selectedEvent = $0 }
                    )
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedEvent) { event in
                ScheduleEventDetailFullScreen(
                    event: event,
                    onClose: { selectedEvent = nil },
                    onOpenMap: {
                        selectedEvent = nil
                        tabRouter.selectedTab = .map
                    },
                    onOpenWebsite: {
                        selectedEvent = nil
                        openURL(URL(string: AppConstants.URLs.universityHome)!)
                    },
                    onOpenCollection: {
                        selectedEvent = nil
                        tabRouter.selectedTab = .collection
                    }
                )
            }
            .onChange(of: tabRouter.focusedScheduleEventID) { _, newValue in
                guard let newValue,
                      let event = modelController.scheduleEvents.first(where: { $0.id == newValue }) else { return }
                selectedDay = event.dayNumber
                selectedEvent = event
                tabRouter.focusedScheduleEventID = nil
            }
        }
    }
}

// MARK: - Festive Banner

private struct ScheduleFestiveBannerView: View {
    let selectedDay: Int
    let totalEvents: Int
    let viewingAddedOnly: Bool

    private var eventsToday: Int { max(1, totalEvents / 7) }

    var body: some View {
        VStack(spacing: 0) {
            ScheduleBuntingView()

            SchedulePennantTitleView(title: "Schedule")
                .padding(.top, 8)

            HStack(spacing: 10) {
                ScheduleStatChip(label: "Day",    value: "\(selectedDay) of 7")
                ScheduleStatChip(label: "Events", value: viewingAddedOnly ? "\(totalEvents) saved" : "\(eventsToday) today")
                ScheduleStatChip(label: "Week",   value: "1 of 1")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }
}

private struct ScheduleBuntingView: View {
    private let flagCount = 8
    private let flagColors: [Color] = [
        ST.hensRed, ST.hensYellow, ST.hensRedSoft, ST.hensYellowSoft,
        ST.hensRed, ST.hensYellow, ST.hensRedSoft, ST.hensYellowSoft
    ]

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(flagCount)
            let ropeY: CGFloat = 18

            var rope = Path()
            rope.move(to: CGPoint(x: 0, y: ropeY))
            rope.addLine(to: CGPoint(x: size.width, y: ropeY))
            context.stroke(rope, with: .color(ST.hensYellow.opacity(0.9)), lineWidth: 1.5)

            for i in 0..<flagCount {
                let cx = CGFloat(i) * spacing + spacing / 2
                let topLeft  = CGPoint(x: cx - spacing * 0.38, y: ropeY)
                let topRight = CGPoint(x: cx + spacing * 0.38, y: ropeY)
                let tip      = CGPoint(x: cx, y: ropeY + 38)

                var flag = Path()
                flag.move(to: topLeft)
                flag.addLine(to: topRight)
                flag.addLine(to: tip)
                flag.closeSubpath()

                let color = flagColors[i % flagColors.count]
                context.fill(flag, with: .color(color.opacity(0.92)))
                context.stroke(flag, with: .color(ST.hensYellow.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 60)
        .background(ST.hensRed.opacity(0.85))
    }
}

private struct SchedulePennantTitleView: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(ST.hensYellow)

            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { _ in
                    Circle()
                        .fill(ST.hensYellowSoft.opacity(0.80))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 32)
        .background(ST.hensRed.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ST.hensYellow, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

private struct ScheduleStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(ST.hensDimText)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ST.hensRed)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: 110)
        .padding(.vertical, 8)
        .background(ST.hensCream)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ST.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Scope Toggle

private struct ScheduleScopeToggleView: View {
    @Binding var viewingAddedOnly: Bool

    var body: some View {
        HStack(spacing: 8) {
            scopeButton(title: "All events", systemImage: "calendar", isSelected: !viewingAddedOnly) {
                viewingAddedOnly = false
            }
            scopeButton(title: "My plan", systemImage: "bookmark.fill", isSelected: viewingAddedOnly) {
                viewingAddedOnly = true
            }
            Spacer()
        }
    }

    private func scopeButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? ST.hensCream : ST.hensRed)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? ST.hensRed : ST.hensWarm)
                    .overlay(
                        Capsule().strokeBorder(isSelected ? ST.hensYellow : ST.hensYellow.opacity(0.5), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Pill Strip

private struct ScheduleDayPillStrip: View {
    let days: [Int]
    let selectedDay: Int
    let events: [DatabaseEvent]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    ScheduleDayPill(
                        day: day,
                        isActive: day == selectedDay,
                        hasEvents: events.contains { $0.dayNumber == day }
                    ) { onSelect(day) }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }
}

private struct ScheduleDayPill: View {
    let day: Int
    let isActive: Bool
    let hasEvents: Bool
    let onTap: () -> Void

    private var date: Date {
        AppConstants.Schedule.weekStart.addingTimeInterval(Double(day - 1) * 86400)
    }
    private var dowLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dowLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(0.7)
                    .foregroundStyle(isActive ? ST.hensYellowSoft : ST.hensDimText)
                Text(dayNumber)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? ST.hensYellow : ST.hensRed)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == 0 && hasEvents
                                  ? (isActive ? ST.hensYellow : ST.hensRed)
                                  : (isActive ? ST.hensYellowSoft.opacity(0.4) : ST.hensMid))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).frame(minWidth: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? ST.hensRed : ST.hensWarm)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isActive ? ST.hensYellow : ST.hensYellow.opacity(0.5), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Event List

private struct ScheduleTimelineEventList: View {
    let sections: [ScheduleEventSection]
    let onTap: (DatabaseEvent) -> Void

    var body: some View {
        if sections.allSatisfy({ $0.items.isEmpty }) {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 36)).foregroundStyle(ST.hensRed.opacity(0.4))
                Text("No events this day")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ST.hensRed)
                Text("Pick another day to see what's happening.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(ST.hensDimText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 60)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sections) { section in
                        // Section header band
                        HStack(spacing: 8) {
                            if section.showsPulse { ScheduleLiveDot(color: section.labelColor) }
                            Text(section.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(section.showsPulse ? section.labelColor : ST.hensRed)
                                .tracking(1.0).textCase(.uppercase)
                            Rectangle()
                                .fill(ST.hensYellow.opacity(0.4))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)

                        ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, presentation in
                            ScheduleTimelineRow(
                                presentation: presentation,
                                isLast: idx == section.items.count - 1,
                                onTap: { onTap(presentation.event) }
                            )
                        }
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct ScheduleLiveDot: View {
    let color: Color
    @State private var pulse = false
    var body: some View {
        Circle().fill(color).frame(width: 5, height: 5)
            .opacity(pulse ? 0.25 : 1.0)
            .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Timeline Row

private struct ScheduleTimelineRow: View {
    @EnvironmentObject private var modelController: ModelController
    let presentation: ScheduleEventPresentation
    let isLast: Bool
    let onTap: () -> Void

    private var timeComponents: (hour: String, rest: String) {
        let parts = presentation.event.timeRange.components(separatedBy: " – ")
        guard let start = parts.first else { return ("?", ":00") }
        let tp = start.components(separatedBy: ":")
        let hour = tp.first ?? "?"
        let rest = tp.count > 1 ? ":\(tp[1])" : ":00"
        return (hour, rest)
    }

    private var dotColor: Color {
        switch presentation.status {
        case .active:      return Color(red: 0.17, green: 0.70, blue: 0.47)
        case .ended:       return ST.hensFadedText
        case .featured:    return ST.hensYellow
        case .upcoming:    return ST.hensRedSoft
        case .unavailable: return ST.hensMid
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                // Time column
                VStack(alignment: .trailing, spacing: 0) {
                    Text(timeComponents.hour)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ST.hensDimText)
                    Text(timeComponents.rest)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(ST.hensFadedText)
                }
                .frame(width: 48, alignment: .trailing).padding(.top, 14).padding(.trailing, 10)

                // Gutter
                VStack(alignment: .center, spacing: 0) {
                    ZStack {
                        Circle().fill(ST.hensWarm).frame(width: 9, height: 9)
                        Circle().fill(dotColor).frame(width: 7, height: 7)
                    }
                    .padding(.top, 14)
                    if !isLast {
                        Rectangle()
                            .fill(ST.hensYellow.opacity(0.35))
                            .frame(width: 1.5).frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 20)

                // Card
                ScheduleEventTimelineCard(
                    presentation: presentation,
                    onToggleAdded: { modelController.toggleEventAddedToSchedule(presentation.event) }
                )
                    .padding(.leading, 8).padding(.vertical, 4).padding(.trailing, 16)
            }
            .opacity(presentation.status == .ended || presentation.status == .unavailable ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Timeline Card

private struct ScheduleEventTimelineCard: View {
    let presentation: ScheduleEventPresentation
    let onToggleAdded: () -> Void

    private var borderColor: Color {
        switch presentation.status {
        case .active:   return Color(red: 0.17, green: 0.70, blue: 0.47).opacity(0.35)
        case .featured: return ST.hensYellow.opacity(0.5)
        case .upcoming: return ST.hensRedSoft.opacity(0.3)
        default:        return ST.hensYellow.opacity(0.4)
        }
    }

    private var bgColor: Color {
        presentation.status == .featured ? ST.hensWarm : ST.hensCream
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rarity stripe
            Rectangle()
                .fill(presentation.collectible != nil ? presentation.collectible!.rarity.rarityColor() : ST.hensMid)
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: 12, bottomLeadingRadius: 12))

            ScheduleEventCardInner(presentation: presentation, onToggleAdded: onToggleAdded)

            if let c = presentation.collectible {
                CollectibleEventPreview(collectible: c)
            }
        }
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor, lineWidth: 1.5))
        .shadow(color: ST.hensRed.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

private struct ScheduleEventCardInner: View {
    let presentation: ScheduleEventPresentation
    let onToggleAdded: () -> Void

    private var rarityStr: String { presentation.collectible?.rarity ?? presentation.event.derivedRarity }
    private var pts: Int { presentation.collectible?.points ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if presentation.status == .active {
                    HStack(spacing: 4) {
                        ScheduleLiveDot(color: Color(red: 0.17, green: 0.70, blue: 0.47))
                        Text("Available now")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.17, green: 0.70, blue: 0.47))
                            .tracking(0.4).textCase(.uppercase)
                    }
                } else {
                    AvailabilityChip(availability: presentation.availability)
                    if presentation.status == .featured {
                        RarityBadge(rarity: rarityStr)
                    } else {
                        Text(presentation.event.eventTypeName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(ST.hensDimText)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(ST.hensMid.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                Spacer(minLength: 0)
                ScheduleAddButtonView(isAdded: presentation.isAdded, onTap: onToggleAdded)
            }

            Text(presentation.event.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ST.hensRed)
                .lineLimit(2).multilineTextAlignment(.leading)

            HStack(spacing: 10) {
                Label(presentation.event.locationName, systemImage: "mappin")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ST.hensDimText).lineLimit(1)
                if pts > 0 {
                    Text("+\(pts) pts")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(ST.hensRed)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ST.hensYellowSoft.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if let message = presentation.availability.message {
                Text(message)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(ST.hensDimText).lineLimit(2)
            } else if presentation.status == .active || presentation.status == .featured {
                Text(presentation.event.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(ST.hensDimText).lineLimit(2)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScheduleAddButtonView: View {
    let isAdded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { onTap() }
        } label: {
            Text(isAdded ? "✓ Added" : "+ Add")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isAdded ? ST.hensRed : ST.hensCream)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isAdded ? ST.hensYellow : ST.hensRed)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isAdded ? ST.hensRed.opacity(0.3) : ST.hensYellow, lineWidth: 1.2))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event detail full-screen (re-themed)

private struct ScheduleEventDetailFullScreen: View {
    @EnvironmentObject private var modelController: ModelController
    let event: DatabaseEvent
    let onClose: () -> Void
    let onOpenMap: () -> Void
    let onOpenWebsite: () -> Void
    let onOpenCollection: () -> Void

    private var collectible: DatabaseCollectible? {
        modelController.collectible(for: event)
    }

    private var availability: PinAvailabilityState {
        modelController.availabilityState(for: event)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ST.hensBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let c = collectible {
                            VStack(alignment: .leading, spacing: 10) {
                                RarityBadge(rarity: c.rarity)
                                Text(c.name)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(ST.hensRed)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ST.hensWarm)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ST.hensYellow, lineWidth: 1.5))
                            .cornerRadius(12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            AvailabilityChip(availability: availability)

                            Text(event.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(ST.hensRed)

                            VStack(alignment: .leading, spacing: 8) {
                                Label(event.timeRange, systemImage: "clock")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(ST.hensDimText)
                                Label(event.locationName, systemImage: "mappin")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(ST.hensDimText)
                            }

                            Text(event.description)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(ST.hensDimText.opacity(0.85))

                            if let message = availability.message {
                                Text(message)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(ST.hensDimText)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ST.hensWarm)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ST.hensYellow, lineWidth: 1.5))
                        .cornerRadius(12)

                        VStack(spacing: 10) {
                            ScheduleDetailActionButton(title: "Open on Map",       systemImage: "map",              action: onOpenMap)
                            ScheduleDetailActionButton(title: "Visit UMD Website", systemImage: "safari",           action: onOpenWebsite)
                            if collectible != nil {
                                ScheduleDetailActionButton(
                                    title: availability.isActive ? "Go to Collection" : "Collection Unavailable",
                                    systemImage: availability.isActive ? "star.square.fill" : availability.symbolName,
                                    isEnabled: availability.isActive,
                                    action: onOpenCollection
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ST.hensRed, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(ST.hensYellow)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

private struct ScheduleDetailActionButton: View {
    let title: String
    let systemImage: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ST.hensRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(ST.hensWarm)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ST.hensYellow, lineWidth: 1.5))
                .cornerRadius(12)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Shared: RarityBadge, AvailabilityChip, CollectibleEventPreview, AvifImage

struct RarityBadge: View {
    let rarity: String
    var body: some View {
        Label(rarity, systemImage: rarity.raritySymbol())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(rarity.rarityColor())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(rarity.rarityTint())
            .clipShape(Capsule())
    }
}

struct AvailabilityChip: View {
    let availability: PinAvailabilityState
    var body: some View {
        Label(availability.label, systemImage: availability.symbolName)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(availability.tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(availability.tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct CollectibleEventPreview: View {
    let collectible: DatabaseCollectible
    var body: some View {
        VStack(spacing: 2) {
            if let name = collectible.imageName {
                AvifImage(named: name)
                    .scaledToFill().frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            } else {
                Text(collectible.emoji).font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(collectible.rarity.rarityTint())
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            Text(collectible.name)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(ST.hensDimText)
                .lineLimit(1).frame(maxWidth: 40)
        }
        .padding(.trailing, 8).padding(.vertical, 6).frame(width: 44)
    }
}

struct AvifImage: View {
    let named: String
    var body: some View {
        if let url = Bundle.main.url(forResource: named, withExtension: "avif"),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable()
        } else {
            Color(red: 0.97, green: 0.88, blue: 0.72)
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview {
    ScheduleScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
