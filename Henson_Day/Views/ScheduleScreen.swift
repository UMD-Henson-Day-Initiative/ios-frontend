import SwiftUI

// MARK: - Schedule screen
/// Day-filtered event schedule. Renders a header with event count, a horizontal
/// strip of day pills, and a vertical timeline of events for the selected day.
/// Supports deep-linking from map pins via `TabRouter.focusedScheduleEventID`.
struct ScheduleScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.openURL) private var openURL
    @State private var selectedDay: Int = 1
    @State private var selectedEvent: DatabaseEvent?

    private var dayEvents: [DatabaseEvent] {
        modelController.scheduleEvents.filter { $0.dayNumber == selectedDay }
    }

    private var days: [Int] {
        let available = Set(modelController.scheduleEvents.map(\.dayNumber))
        return Array(available).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScheduleHeaderSection(
                    selectedDay: selectedDay,
                    totalEvents: modelController.scheduleEvents.count
                )
                DayPillStrip(
                    days: days.isEmpty ? Array(1...7) : days,
                    selectedDay: selectedDay,
                    events: modelController.scheduleEvents
                ) { day in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedDay = day
                    }
                }
                Divider().background(Color(hex: "#EAEAEE"))
                TimelineEventList(
                    events: dayEvents,
                    catalog: modelController.collectibleCatalog,
                    onTap: { selectedEvent = $0 }
                )
            }
            .background(Color(hex: "#F2F2F0").ignoresSafeArea())
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileToolbarButton()
                }
            }
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

// MARK: - Header section

private struct ScheduleHeaderSection: View {
    let selectedDay: Int
    let totalEvents: Int

    private var weekProgress: Double { Double(selectedDay - 1) / 6.0 }
    private var eventsToday: Int { max(1, totalEvents / 7) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Day \(selectedDay) of 7")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#3D3D42"))
                    Text("\(eventsToday) events today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#8A8A92"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 10)

            WeekProgressBar(progress: weekProgress, selectedDay: selectedDay)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
        }
        .background(Color(hex: "#F2F2F0"))
    }
}

// MARK: - Week progress bar

private struct WeekProgressBar: View {
    let progress: Double
    let selectedDay: Int

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("Week progress")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8A8A92"))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("\(selectedDay - 1) attended \u{00B7} 4 pts/event")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8A8A92"))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#EAEAEE")).frame(height: 4)
                    // Tick marks
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            if i > 0 { Rectangle().fill(Color(hex: "#F2F2F0")).frame(width: 1.5, height: 4) }
                            if i < 6 { Spacer() }
                        }
                    }.frame(height: 4)
                    // Fill
                    let w = geo.size.width * max(0, min(1, progress))
                    Capsule()
                        .fill(LinearGradient(colors: [DS.Color.primary, Color(hex: "#FF4060")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: w, height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                    if progress > 0 {
                        Circle()
                            .fill(DS.Color.primary)
                            .frame(width: 8, height: 8)
                            .shadow(color: DS.Color.primary.opacity(0.5), radius: 4)
                            .offset(x: max(0, w - 4))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                    }
                }
                .frame(height: 8)
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Day pill strip

private struct DayPillStrip: View {
    let days: [Int]
    let selectedDay: Int
    let events: [DatabaseEvent]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    DayPill(
                        day: day,
                        isActive: day == selectedDay,
                        hasEvents: events.contains { $0.dayNumber == day }
                    ) { onSelect(day) }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color(hex: "#F2F2F0"))
    }
}

private struct DayPill: View {
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
                    .font(.system(size: 9, weight: .bold)).tracking(0.7)
                    .foregroundStyle(isActive ? Color.white.opacity(0.7) : Color(hex: "#8A8A92"))
                Text(dayNumber)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isActive ? .white : Color(hex: "#141418"))
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == 0 && hasEvents
                                  ? (isActive ? Color.white : DS.Color.primary)
                                  : (isActive ? Color.white.opacity(0.4) : Color(hex: "#C8C8D0")))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).frame(minWidth: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? DS.Color.primary : .white)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isActive ? Color.clear : Color(hex: "#EAEAEE"), lineWidth: 1.5))
            )
            .shadow(color: isActive ? DS.Color.primary.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event status

private enum EventStatus { case done, live, upcoming, featured }

private extension DatabaseEvent {
    // Friendly type name based on pinType
    // (eventTypeName already added to DatabaseEvent in Database.swift)

    // Rarity string derived from pinType for status coloring
    var derivedRarity: String {
        switch pinType {
        case .concert, .homebase: return "Legendary"
        case .event, .battle:     return "Rare"
        default:                  return "Common"
        }
    }

    func status(in catalog: [DatabaseCollectible]) -> EventStatus {
        let c = catalog.first { $0.name == collectibleName }
        if c?.rarity == "Legendary" { return .featured }
        let eventDate = AppConstants.Schedule.weekStart.addingTimeInterval(Double(dayNumber - 1) * 86400)
        let dayEnd = Calendar.current.startOfDay(for: eventDate).addingTimeInterval(86400)
        let now = Date()
        if now > dayEnd { return .done }
        let dayStart = Calendar.current.startOfDay(for: eventDate)
        if now >= dayStart && now <= dayEnd { return .live }
        return .upcoming
    }
}

// MARK: - Timeline event list

private struct TimelineEventList: View {
    let events: [DatabaseEvent]
    let catalog: [DatabaseCollectible]
    let onTap: (DatabaseEvent) -> Void

    private func collectible(for event: DatabaseEvent) -> DatabaseCollectible? {
        guard let name = event.collectibleName else { return nil }
        return catalog.first { $0.name == name }
    }

    private var groups: [(label: String, labelColor: Color, items: [DatabaseEvent])] {
        var done: [DatabaseEvent] = []
        var live: [DatabaseEvent] = []
        var upcoming: [DatabaseEvent] = []
        for e in events {
            switch e.status(in: catalog) {
            case .done:              done.append(e)
            case .live:              live.append(e)
            case .upcoming, .featured: upcoming.append(e)
            }
        }
        var result: [(String, Color, [DatabaseEvent])] = []
        if !done.isEmpty     { result.append(("Earlier",        Color(hex: "#8A8A92"), done)) }
        if !live.isEmpty     { result.append(("Happening now",  Color(hex: "#FF6B00"), live)) }
        if !upcoming.isEmpty { result.append(("Upcoming",       Color(hex: "#8A8A92"), upcoming)) }
        if result.isEmpty    { result.append(("Events",         Color(hex: "#8A8A92"), events)) }
        return result
    }

    var body: some View {
        if events.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 36)).foregroundStyle(DS.Color.primary.opacity(0.4))
                Text("No events this day").font(DS.Typography.title2)
                Text("Pick another day to see what's happening.")
                    .font(DS.Typography.body).foregroundStyle(DS.Color.neutral)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 60)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groups, id: \.label) { group in
                        HStack(spacing: 8) {
                            if group.label == "Happening now" { LiveDot() }
                            Text(group.label)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(group.labelColor)
                                .tracking(1.0).textCase(.uppercase)
                            Rectangle()
                                .fill(group.label == "Happening now"
                                      ? Color(hex: "#FF6B00").opacity(0.2)
                                      : Color(hex: "#EAEAEE"))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)

                        ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, event in
                            ScheduleTimelineRow(
                                event: event,
                                collectible: collectible(for: event),
                                isLast: idx == group.items.count - 1,
                                status: event.status(in: catalog),
                                onTap: { onTap(event) }
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

private struct LiveDot: View {
    @State private var pulse = false
    var body: some View {
        Circle().fill(Color(hex: "#FF6B00")).frame(width: 5, height: 5)
            .opacity(pulse ? 0.25 : 1.0)
            .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

// MARK: - Timeline row

private struct ScheduleTimelineRow: View {
    let event: DatabaseEvent
    let collectible: DatabaseCollectible?
    let isLast: Bool
    let status: EventStatus
    let onTap: () -> Void

    private var timeComponents: (hour: String, rest: String) {
        let parts = event.timeRange.components(separatedBy: " – ")
        guard let start = parts.first else { return ("?", ":00") }
        let tp = start.components(separatedBy: ":")
        let hour = tp.first ?? "?"
        let rest = tp.count > 1 ? ":\(tp[1])" : ":00"
        return (hour, rest)
    }

    private var dotColor: Color {
        switch status {
        case .live:     return Color(hex: "#FF6B00")
        case .done:     return Color(hex: "#2DB37A")
        case .featured: return Color(hex: "#E8A800")
        case .upcoming: return Color(hex: "#C8C8D0")
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                // Time column
                VStack(alignment: .trailing, spacing: 0) {
                    Text(timeComponents.hour)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#3D3D42"))
                    Text(timeComponents.rest)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(hex: "#8A8A92"))
                }
                .frame(width: 48, alignment: .trailing).padding(.top, 14).padding(.trailing, 10)

                // Gutter
                VStack(alignment: .center, spacing: 0) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 9, height: 9)
                        Circle().fill(dotColor).frame(width: 7, height: 7)
                    }
                    .padding(.top, 14)
                    if !isLast {
                        Rectangle()
                            .fill(status == .live ? Color(hex: "#FF6B00").opacity(0.2) : Color(hex: "#EAEAEE"))
                            .frame(width: 1.5).frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 20)

                // Card
                EventTimelineCard(event: event, collectible: collectible, status: status)
                    .padding(.leading, 8).padding(.vertical, 4).padding(.trailing, 20)
            }
            .opacity(status == .done ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event timeline card

private struct EventTimelineCard: View {
    let event: DatabaseEvent
    let collectible: DatabaseCollectible?
    let status: EventStatus

    @ViewBuilder private var bg: some View {
        if status == .featured {
            LinearGradient(colors: [Color(hex: "#FFFCF0"), Color(hex: "#FFF7DC")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.white
        }
    }

    private var borderColor: Color {
        switch status {
        case .live:     return Color(hex: "#FF6B00").opacity(0.25)
        case .featured: return Color(hex: "#E8A800").opacity(0.25)
        default:        return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Rarity stripe
            Rectangle()
                .fill(collectible != nil ? collectible!.rarity.rarityColor() : Color(hex: "#C8C8D0"))
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: 14, bottomLeadingRadius: 14))

            EventCardInner(event: event, collectible: collectible, status: status)

            if let c = collectible {
                CollectibleEventPreview(collectible: c)
            }
        }
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(borderColor, lineWidth: 1.5))
        .shadow(color: Color.black.opacity(0.055), radius: 6, x: 0, y: 2)
    }
}

private struct EventCardInner: View {
    let event: DatabaseEvent
    let collectible: DatabaseCollectible?
    let status: EventStatus

    private var rarityStr: String { collectible?.rarity ?? event.derivedRarity }
    private var pts: Int { collectible?.points ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if status == .live {
                    HStack(spacing: 4) {
                        LiveDot()
                        Text("Live now").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#FF6B00")).tracking(0.4).textCase(.uppercase)
                    }
                } else {
                    RarityBadge(rarity: rarityStr)
                    Text(event.eventTypeName)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: "#8A8A92"))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(hex: "#F0F0F3")).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 0)
                ScheduleAddButton()
            }
            Text(event.title)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "#141418"))
                .lineLimit(2).multilineTextAlignment(.leading)
            HStack(spacing: 10) {
                Label(event.locationName, systemImage: "mappin")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color(hex: "#8A8A92")).lineLimit(1)
                if pts > 0 {
                    Text("+\(pts) pts")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#8A8A92"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.black.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            if status == .live || status == .featured {
                Text(event.description)
                    .font(.system(size: 11)).foregroundStyle(Color(hex: "#8A8A92")).lineLimit(2)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScheduleAddButton: View {
    @State private var isAdded = false
    var body: some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isAdded.toggle() } } label: {
            Text(isAdded ? "✓ Added" : "+ Add")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isAdded ? .white : DS.Color.primary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isAdded ? Color(hex: "#2DB37A") : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isAdded ? Color.clear : DS.Color.primary, lineWidth: 1.5))
                )
        }
        .buttonStyle(.plain)
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
                .font(.system(size: 8, weight: .semibold)).foregroundStyle(Color(hex: "#8A8A92"))
                .lineLimit(1).frame(maxWidth: 40)
        }
        .padding(.trailing, 8).padding(.vertical, 6).frame(width: 44)
    }
}

// MARK: - Rarity badge (shared)

struct RarityBadge: View {
    let rarity: String

    var body: some View {
        Label(rarity, systemImage: rarity.raritySymbol())
            .font(DS.Typography.caption)
            .foregroundStyle(rarity.rarityColor())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(rarity.rarityTint())
            .clipShape(Capsule())
    }
}

// MARK: - Event detail full-screen

private struct ScheduleEventDetailFullScreen: View {
    @EnvironmentObject private var modelController: ModelController
    let event: DatabaseEvent
    let onClose: () -> Void
    let onOpenMap: () -> Void
    let onOpenWebsite: () -> Void
    let onOpenCollection: () -> Void

    private var collectible: DatabaseCollectible? {
        guard let name = event.collectibleName else { return nil }
        return modelController.collectibleCatalog.first { $0.name == name }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.card) {
                        if let c = collectible {
                            VStack(alignment: .leading, spacing: 10) {
                                RarityBadge(rarity: c.rarity)
                                Text(c.name)
                                    .font(DS.Typography.title1)
                                    .foregroundStyle(DS.Color.campusNight)
                            }
                            .padding(DS.Spacing.cardPad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Color.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                            .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(event.title)
                                .font(DS.Typography.display)
                                .foregroundStyle(DS.Color.campusNight)

                            VStack(alignment: .leading, spacing: 8) {
                                Label(event.timeRange, systemImage: "clock")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Color.neutral)
                                Label(event.locationName, systemImage: "mappin")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Color.neutral)
                            }

                            Text(event.description)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.campusNight.opacity(0.75))
                        }
                        .padding(DS.Spacing.cardPad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)

                        VStack(spacing: 10) {
                            DetailActionButton(title: "Open on Map", systemImage: "map", action: onOpenMap)
                            DetailActionButton(title: "Visit UMD Website", systemImage: "safari", action: onOpenWebsite)
                            if collectible != nil {
                                DetailActionButton(title: "Go to Collection", systemImage: "star.square.fill", action: onOpenCollection)
                            }
                        }
                    }
                    .padding(DS.Spacing.screenH)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(DS.Color.neutral)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

// MARK: - Action button

private struct DetailActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.cardPad)
                .background(DS.Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .shadow(color: DS.Shadow.cardColor, radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - AVIF image helper (shared with CollectionScreen)

struct AvifImage: View {
    let named: String
    var body: some View {
        if let url = Bundle.main.url(forResource: named, withExtension: "avif"),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable()
        } else {
            Color(hex: "#252A3E")
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
