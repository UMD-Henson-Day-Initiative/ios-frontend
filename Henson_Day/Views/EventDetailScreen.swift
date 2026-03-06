//
//  EventDetailScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// EventDetailScreen.swift

import SwiftUI

struct EventDetailScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let eventId: String

    var event: Event? {
        appState.events.first { $0.id == eventId }
    }

    var collectible: Collectible? {
        guard let event, let id = event.collectibleId else { return nil }
        return appState.collectibles.first { $0.id == id }
    }

    var similarEvents: [Event] {
        appState.events.filter { $0.id != eventId }.prefix(2).map { $0 }
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
                                Text(c.emoji)
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
                                Text(event.name)
                                    .font(.title2.weight(.semibold))

                                HStack(spacing: 6) {
                                    EventTypeChip(type: event.type)
                                    Label("Day \(event.day)", systemImage: "calendar")
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
                                Text(event.time)
                            }
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(event.location)
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
                                    Text(c.emoji)
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
                                            if c.rarity == .legendary {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(Color.purple)
                                                    .font(.caption)
                                            }
                                        }
                                        Text(c.flavorText)
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
                                                    Text(e.name)
                                                        .font(.subheadline.weight(.medium))
                                                    Text("\(e.time) • \(e.location)")
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
                                // TODO: open Maps / navigation
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

struct EventTypeChip: View {
    let type: EventType

    var body: some View {
        let (text, color): (String, Color) = {
            switch type {
            case .homebase: return ("Homebase", Color("UMDRed"))
            case .rare: return ("Rare", Color("UMDGold"))
            case .common: return ("Event", .gray)
            }
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


