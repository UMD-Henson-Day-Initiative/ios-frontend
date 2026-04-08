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
                Color.white.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        // Fun muppet-themed header banner
                        ScheduleHeaderBanner()
                            .padding(.horizontal, DS.Spacing.screenH)

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
        .background(collectible.map { $0.rarity.rarityTint() } ?? DS.Color.surfaceElevated)
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

// MARK: - Header banner

private struct ScheduleHeaderBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week's Events")
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.campusNight)
                Text("Attend events, collect muppets, earn points!")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.neutral)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(DS.Color.primaryTint)
                    .frame(width: 60, height: 60)
                Text("🐸")
                    .font(.system(size: 32))
            }
        }
        .padding(DS.Spacing.cardPad)
        .background(
            LinearGradient(
                colors: [DS.Color.primaryTint, DS.Color.Rarity.legendaryTint],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Color.primary.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ScheduleScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
