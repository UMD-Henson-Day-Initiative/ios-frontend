import SwiftUI

struct ScheduleScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedDay: Int = 1

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
                                    ScheduleEventCard(event: event)
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
        .environmentObject(ModelController())
}
