//
//  HomeScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// HomeScreen.swift

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var appState: AppState

    var topThree: [LeaderboardUser] {
        Array(appState.leaderboardUsers.sorted { $0.score > $1.score }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(Color("UMDRed").opacity(0.9))
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        LinearGradient(
                            colors: [Color.black.opacity(0.4), .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Week-long AR Adventure")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("UMDGold"))
                            .clipShape(Capsule())

                            Text("Henson Week")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)

                            Text("Explore campus. Collect creatures.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding()
                    }

                    Text("Join the AR scavenger hunt across UMD. Attend events, discover whimsical creatures compete with friends.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    // CTAs
                    VStack(spacing: 12) {
                        NavigationLink("Start Exploring") {
                            MapScreen()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("UMDRed"))
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)

                        HStack(spacing: 12) {
                            NavigationLink {
                                ScheduleScreen()
                            } label: {
                                Label("Schedule", systemImage: "calendar")
                            }
                            .buttonStyle(.bordered)
                            .tint(Color("UMDRed"))
                            .frame(maxWidth: .infinity)

                            NavigationLink {
                                CollectionScreen()
                            } label: {
                                Label("Collection", systemImage: "cube.box.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(Color("UMDGold"))
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Top collectors banner
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top 3 Collectors")
                                .font(.headline)
                            Spacer()
                            NavigationLink("View Full Leaderboard") {
                                LeaderboardScreen()
                            }
                            .font(.caption)
                        }

                        ForEach(Array(topThree.enumerated()), id: \.element.id) { index, user in
                            NavigationLink {
                                LeaderboardScreen()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack(alignment: .topTrailing) {
                                        Text(user.avatarEmoji)
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                LinearGradient(
                                                    colors: [
                                                        Color("UMDRed").opacity(0.2),
                                                        Color("UMDGold").opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 2)
                                            )

                                        if index == 0 {
                                            Text("👑")
                                                .font(.caption2)
                                                .padding(4)
                                                .background(Color("UMDGold"))
                                                .clipShape(Circle())
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("#\(index + 1)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(user.name)
                                                .font(.subheadline.weight(.medium))
                                        }

                                        Text("\(user.eventsVisited) events • \(user.score) pts")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉")
                                        .font(.title3)
                                }
                                .padding(10)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(radius: 4)

                    // Stats
                    HStack(spacing: 12) {
                        StatChip(title: "Events", value: "90+", color: Color("UMDRed"))
                        StatChip(title: "Collectibles", value: "\(appState.collectibles.count)", color: Color("UMDGold"))
                        StatChip(title: "Days", value: "7", color: .orange)
                    }
                }
                .padding()
            }
            .navigationTitle("Henson Week")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeScreen()
        .environmentObject(AppState())
}
