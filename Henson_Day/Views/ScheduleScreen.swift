import SwiftUI

/// Event schedule view with day-based filtering. Users pick a day tab to see
/// that day's events, tap an event for details, and can navigate to the map
/// or open the university website. Supports deep-linking via `TabRouter.focusedScheduleEventID`.
struct ScheduleScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.openURL) private var openURL
    @State private var selectedDay: Int = 1
    @State private var selectedEvent: DatabaseEvent?
    @Namespace private var dayChipNS

    private var dayEvents: [DatabaseEvent] {
        modelController.scheduleEvents.filter { $0.dayNumber == selectedDay }
    }

    private var days: [Int] {
        let available = Set(modelController.scheduleEvents.map(\.dayNumber))
        return Array(available).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(days.isEmpty ? Array(1...7) : days, id: \.self) { day in
                                    ScheduleDayChip(
                                        day: day,
                                        isSelected: day == selectedDay,
                                        namespace: dayChipNS
                                    ) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            selectedDay = day
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screenH)
                            .padding(.vertical, 6)
                        }

                        VStack(spacing: DS.Spacing.card) {
                            if dayEvents.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 36))
                                        .foregroundStyle(DS.Color.primary.opacity(0.4))
                                    Text("No events this day")
                                        .font(DS.Typography.title2)
                                    Text("Pick another day to see what's happening.")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(DS.Color.neutral)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 50)
                            } else {
                                ForEach(dayEvents) { event in
                                    Button {
                                        selectedEvent = event
                                    } label: {
                                        ScheduleEventCard(event: event)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, DS.Spacing.screenH)
                                }
                            }
                        }
                        .padding(.bottom, DS.Spacing.section)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Day chip

private struct ScheduleDayChip: View {
    let day: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Day \(day)")
                .font(DS.Typography.label)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : DS.Color.neutral)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(DS.Color.primary)
                            .matchedGeometryEffect(id: "dayChipBackground", in: namespace)
                    } else {
                        Capsule()
                            .fill(DS.Color.surfaceElevated)
                            .overlay(Capsule().strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 1))
                    }
                }
                .shadow(
                    color: isSelected ? DS.Color.primary.opacity(0.25) : .clear,
                    radius: 6, x: 0, y: 2
                )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Event card

struct ScheduleEventCard: View {
    @EnvironmentObject private var modelController: ModelController
    let event: DatabaseEvent

    private var collectible: DatabaseCollectible? {
        guard let name = event.collectibleName else { return nil }
        return modelController.collectibleCatalog.first { $0.name == name }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(collectible.map { $0.rarity.rarityColor() } ?? DS.Color.neutral)
                .frame(width: 4)
                .padding(.vertical, 14)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 8) {
                if let c = collectible {
                    HStack(spacing: 6) {
                        RarityBadge(rarity: c.rarity)
                        Text(c.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.neutral)
                            .lineLimit(1)
                    }
                }

                Text(event.title)
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.campusNight)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 14) {
                    Label(event.timeRange, systemImage: "clock")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Color.neutral)

                    Label(event.locationName, systemImage: "mappin")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Color.neutral)
                        .lineLimit(1)
                }

                Text(event.description)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.neutral)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
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
                DS.Color.surface.ignoresSafeArea()
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

#Preview {
    ScheduleScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
import SwiftUI

/// Event schedule view with day-based filtering. Users pick a day tab to see
/// that day's events, tap an event for details, and can navigate to the map
/// or open the university website. Supports deep-linking via `TabRouter.focusedScheduleEventID`.
struct ScheduleScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @Environment(\.openURL) private var openURL
    @State private var selectedDay: Int = 1
    @State private var selectedEvent: DatabaseEvent?
    @Namespace private var dayChipNS

    private var dayEvents: [DatabaseEvent] {
        modelController.scheduleEvents.filter { $0.dayNumber == selectedDay }
    }

    private var days: [Int] {
        let available = Set(modelController.scheduleEvents.map(\.dayNumber))
        return Array(available).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
<<<<<<< HEAD
                DS.Color.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(days.isEmpty ? Array(1...7) : days, id: \.self) { day in
                                    ScheduleDayChip(
                                        day: day,
                                        isSelected: day == selectedDay,
                                        namespace: dayChipNS
                                    ) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            selectedDay = day
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screenH)
                            .padding(.vertical, 6)
                        }

                        VStack(spacing: DS.Spacing.card) {
                            if dayEvents.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 36))
                                        .foregroundStyle(DS.Color.primary.opacity(0.4))
                                    Text("No events this day")
                                        .font(DS.Typography.title2)
                                    Text("Pick another day to see what's happening.")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(DS.Color.neutral)
=======
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(days.isEmpty ? Array(1...7) : days, id: \.self) { day in
                                    ScheduleDayChip(day: day, isSelected: day == selectedDay) {
                                        selectedDay = day
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Day \(selectedDay) Events")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color("UMDRed"))
                                .padding(.horizontal)

                            if dayEvents.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color("UMDRed").opacity(0.5))
                                    Text("No events this day")
                                        .font(.headline)
                                    Text("Pick another day to see what's happening.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 50)
                            } else {
<<<<<<< HEAD
                                ForEach(dayEvents) { event in
                                    Button {
                                        selectedEvent = event
                                    } label: {
                                        ScheduleEventCard(event: event)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, DS.Spacing.screenH)
=======
                                VStack(spacing: 14) {
                                    ForEach(dayEvents) { event in
                                        Button {
                                            selectedEvent = event
                                        } label: {
                                            ScheduleEventCard(event: event)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal)
                                    }
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
                                }
                            }
                        }
                        .padding(.bottom, DS.Spacing.section)
                    }
<<<<<<< HEAD
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
=======
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Schedule")
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
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

// MARK: - Day chip

private struct ScheduleDayChip: View {
    let day: Int
    let isSelected: Bool
<<<<<<< HEAD
    let namespace: Namespace.ID
=======
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Day \(day)")
<<<<<<< HEAD
                .font(DS.Typography.label)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : DS.Color.neutral)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(DS.Color.primary)
                            .matchedGeometryEffect(id: "dayChipBackground", in: namespace)
                    } else {
                        Capsule()
                            .fill(DS.Color.surfaceElevated)
                            .overlay(Capsule().strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: 1))
                    }
                }
                .shadow(
                    color: isSelected ? DS.Color.primary.opacity(0.25) : .clear,
                    radius: 6, x: 0, y: 2
                )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Event card

struct ScheduleEventCard: View {
=======
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSelected ? Color("UMDRed") : Color.white)
                .foregroundStyle(isSelected ? Color.white : Color("UMDRed"))
                .clipShape(Capsule())
                .shadow(
                    color: Color("UMDRed").opacity(isSelected ? 0.3 : 0.1),
                    radius: isSelected ? 6 : 2,
                    x: 0, y: 2
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color("UMDRed").opacity(isSelected ? 0 : 0.3), lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Rarity helpers

private func rarityColor(for rarity: String) -> Color {
    switch rarity.lowercased() {
    case "legendary": return Color(red: 0.95, green: 0.66, blue: 0.0)
    case "rare":      return Color("UMDRed")
    default:          return Color(red: 0.2, green: 0.7, blue: 0.4)
    }
}

private func rarityEmoji(for rarity: String) -> String {
    switch rarity.lowercased() {
    case "legendary": return "✨"
    case "rare":      return "💎"
    default:          return "⭐️"
    }
}

// MARK: - Event Card

private struct ScheduleEventCard: View {
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
    @EnvironmentObject private var modelController: ModelController
    let event: DatabaseEvent

    private var collectible: DatabaseCollectible? {
        guard let name = event.collectibleName else { return nil }
        return modelController.collectibleCatalog.first { $0.name == name }
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
<<<<<<< HEAD
                .fill(collectible.map { $0.rarity.rarityColor() } ?? DS.Color.neutral)
                .frame(width: 4)
                .padding(.vertical, 14)
                .padding(.leading, 14)
=======
                .fill(Color("UMDRed"))
                .frame(width: 5)
                .padding(.vertical, 14)
                .padding(.leading, 12)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)

            VStack(alignment: .leading, spacing: 8) {
                if let c = collectible {
                    HStack(spacing: 6) {
<<<<<<< HEAD
                        RarityBadge(rarity: c.rarity)
                        Text(c.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.neutral)
                            .lineLimit(1)
=======
                        Text("\(rarityEmoji(for: c.rarity)) \(c.rarity)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(rarityColor(for: c.rarity))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(rarityColor(for: c.rarity).opacity(0.12))
                            .clipShape(Capsule())

                        Text(c.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
                    }
                }

                Text(event.title)
<<<<<<< HEAD
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.campusNight)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 14) {
                    Label(event.timeRange, systemImage: "clock")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Color.neutral)

                    Label(event.locationName, systemImage: "mappin")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Color.neutral)
=======
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    Label(event.timeRange, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(event.locationName, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
                        .lineLimit(1)
                }

                Text(event.description)
<<<<<<< HEAD
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.neutral)
                    .lineLimit(2)
=======
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .lineLimit(3)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
<<<<<<< HEAD
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
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
=======
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Event Detail Sheet
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)

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
<<<<<<< HEAD
                DS.Color.surface.ignoresSafeArea()
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
=======
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = collectible {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(rarityEmoji(for: c.rarity)) \(c.rarity) Collectible")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(rarityColor(for: c.rarity))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(rarityColor(for: c.rarity).opacity(0.14))
                                    .clipShape(Capsule())

                                Text(c.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color("UMDRed"))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(event.title)
                                .font(.title2.weight(.bold))

                            VStack(alignment: .leading, spacing: 6) {
                                Label(event.timeRange, systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Label(event.locationName, systemImage: "mappin.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(event.description)
                                .font(.body)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)

                        VStack(spacing: 12) {
                            DetailActionButton(title: "Open on Map", systemImage: "map") { onOpenMap() }
                            DetailActionButton(title: "Visit UMD Website", systemImage: "safari") { onOpenWebsite() }
                            if collectible != nil {
                                DetailActionButton(title: "Go to Collection", systemImage: "cube.box.fill") { onOpenCollection() }
                            }
                        }
                    }
                    .padding(16)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
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

<<<<<<< HEAD
// MARK: - Action button
=======
// MARK: - Action Button
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)

private struct DetailActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
<<<<<<< HEAD
                .font(DS.Typography.label)
                .foregroundStyle(DS.Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.cardPad)
                .background(DS.Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .shadow(color: DS.Shadow.cardColor, radius: 6, x: 0, y: 2)
=======
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("UMDRed"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
>>>>>>> 69c751a (Enhance event details and UI in ScheduleScreen, add Leaderboard tab)
        }
    }
}

#Preview {
    ScheduleScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
