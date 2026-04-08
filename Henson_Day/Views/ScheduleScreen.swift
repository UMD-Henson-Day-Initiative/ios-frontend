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

    private var dayEvents: [DatabaseEvent] {
        modelController.scheduleEvents.filter { $0.dayNumber == selectedDay }
    }

    private var days: [Int] {
        let available = Set(modelController.scheduleEvents.map(\.dayNumber))
        return Array(available).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(days.isEmpty ? Array(1...7) : days, id: \.self) { day in
                                FilterChip(label: "Day \(day)", isSelected: day == selectedDay) {
                                    selectedDay = day
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day \(selectedDay) Schedule")
                            .font(.headline)
                            .padding(.horizontal)

                        if dayEvents.isEmpty {
                            VStack(spacing: 8) {
                                Text("No events for this day")
                                    .font(.headline)
                                Text("Choose another day to see upcoming activities.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dayEvents) { event in
                                    Button {
                                        selectedEvent = event
                                    } label: {
                                        ScheduleEventCard(event: event)
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
            .fullScreenCover(item: $selectedEvent) { event in
                ScheduleEventDetailFullScreen(
                    event: event,
                    onClose: {
                        selectedEvent = nil
                    },
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

private struct ScheduleEventDetailFullScreen: View {
    let event: DatabaseEvent
    let onClose: () -> Void
    let onOpenMap: () -> Void
    let onOpenWebsite: () -> Void
    let onOpenCollection: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.title)
                        .font(.title2.weight(.bold))

                    Text(event.metadataLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(event.description)
                        .font(.body)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Button("Open on Map") { onOpenMap() }
                            .font(.subheadline.weight(.semibold))

                        Button("Visit UMD Website") { onOpenWebsite() }
                            .font(.subheadline.weight(.semibold))

                        if event.collectibleName != nil {
                            Button("Go to Collection") { onOpenCollection() }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.gray)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

private struct ScheduleEventCard: View {
    let event: DatabaseEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.pinType.displayLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(event.pinType.headerColor.opacity(0.18))
                    .clipShape(Capsule())

                Spacer()

                Text(event.timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(event.title)
                .font(.headline)

            Text(event.metadataLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(event.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let collectibleName = event.collectibleName {
                Text("Collectible: \(collectibleName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("UMDRed"))
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    ScheduleScreen()
        .environmentObject(ModelController.preview())
        .environmentObject(TabRouter())
}
