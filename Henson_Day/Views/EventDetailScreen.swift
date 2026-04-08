//
//  EventDetailScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// EventDetailScreen.swift

import SwiftUI
import MapKit

struct EventDetailScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @Environment(\.dismiss) private var dismiss

    let eventId: String

    private var event: DatabaseEvent? {
        modelController.scheduleEvents.first { $0.id == eventId }
    }

    private var collectible: DatabaseCollectible? {
        guard let collectibleName = event?.collectibleName else { return nil }
        return modelController.collectibleCatalog.first { $0.name == collectibleName }
    }

    private var similarEvents: [DatabaseEvent] {
        Array(modelController.scheduleEvents.filter { $0.id != eventId }.prefix(2))
    }

    private func collectibleEmoji(for collectibleName: String) -> String {
        switch collectibleName {
        case "Stadium Stomper": return "🤖"
        case "Mall Muppet": return "🧸"
        case "Soundwave Snare": return "🐦"
        case "Quantum Smth": return "✈️"
        case "Finale Flare": return "🔥"
        default: return "✨"
        }
    }

    private func descriptionForCollectible(_ collectible: DatabaseCollectible) -> String {
        "Find this collectible near \(collectible.location) to earn \(collectible.points) points."
    }

    private func openMapsForEvent(_ event: DatabaseEvent) {
        let query = event.locationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.locationName
        if let mapsURL = URL(string: "maps://maps.apple.com/?q=\(query)") ?? URL(string: "https://maps.apple.com/?q=\(query)") {
            UIApplication.shared.open(mapsURL)
        }
    }

    var body: some View {
        if let event {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero / header block
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color("UMDRed").opacity(0.25),
                                             Color("UMDGold").opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 220)

                        if let c = collectible {
                            VStack {
                                Spacer()
                                Text(collectibleEmoji(for: c.name))
                                    .font(.system(size: 72))
                                    .padding(24)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 6)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.primary)
                                .padding(8)
                                .background(Color(.systemBackground).opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                                .padding()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        // Title + type badges
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.title)
                                    .font(.title2.weight(.semibold))

                                HStack(spacing: 6) {
                                    EventTypeChip(pinType: event.pinType)
                                    Label("Day \(event.dayNumber)", systemImage: "calendar")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemBackground))
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()
                        }

                        // Time, location, attendees placeholder
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                Text(event.timeRange)
                            }
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(event.locationName)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Divider()

                        // About
                        Text("About This Event")
                            .font(.headline)
                        Text(event.description)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        // Collectible card
                        if let c = collectible {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available Collectible")
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Text(collectibleEmoji(for: c.name))
                                        .font(.largeTitle)
                                        .frame(width: 64, height: 64)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color("UMDGold").opacity(0.25))
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(c.name)
                                                .font(.subheadline.weight(.medium))
                                            if c.rarity == "Legendary" {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(Color.purple)
                                                    .font(.caption)
                                            }
                                        }
                                        Text(descriptionForCollectible(c))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text("+\(c.points) points")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color("UMDRed"))
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color("UMDGold").opacity(0.4))
                                )
                            }
                        }

                        // Similar
                        if !similarEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("You Might Also Like")
                                    .font(.headline)
                                VStack(spacing: 8) {
                                    ForEach(similarEvents) { e in
                                        NavigationLink {
                                            EventDetailScreen(eventId: e.id)
                                        } label: {
                                            HStack(spacing: 10) {
                                                Text("🎪")
                                                    .font(.title3)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(e.title)
                                                        .font(.subheadline.weight(.medium))
                                                    Text("\(e.timeRange) • \(e.locationName)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(10)
                                            .background(Color(.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .shadow(radius: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            Button {
                                openMapsForEvent(event)
                            } label: {
                                Label("Get Directions", systemImage: "location.north.line")
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            if collectible != nil {
                                NavigationLink {
                                    ARCaptureScreen(collectibleId: collectible!.id)
                                } label: {
                                    Label("Capture Now", systemImage: "sparkles")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("UMDRed"))
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
        } else {
            Text("Event not found")
        }
    }
}

#Preview("Event Detail") {
    NavigationStack {
        EventDetailScreen(eventId: Database.events.first?.id ?? "")
    }
    .environmentObject(ModelController.preview())
}

struct EventTypeChip: View {
    let pinType: PinType

    var body: some View {
        let (text, color): (String, Color) = {
            (pinType.displayLabel, pinType.headerColor)
        }()

        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}


