//  HomeScreen.swift
//  Henson_Day
//
//  File Description: This file defines the HomeScreen, the main landing screen of the Henson Day
//  app. It displays a hero banner, a description of the scavenger hunt, navigation CTAs to the
//  map, schedule, and collection tabs, a top three collectors leaderboard preview, and summary
//  stat chips. It also defines a private Color extension for initializing colors from hex strings.
//

// HomeScreen.swift

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    var topThree: [PlayerEntity] {
        Array(modelController.leaderboardUsers.prefix(3))
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
                        Button("Start Exploring") {
                            tabRouter.selectedTab = .map
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("UMDRed"))
                        .frame(maxWidth: .infinity)
                        .controlSize(.large)

                        HStack(spacing: 12) {
                            Button {
                                tabRouter.selectedTab = .schedule
                            } label: {
                                Label("Schedule", systemImage: "calendar")
                            }
                            .buttonStyle(.bordered)
                            .tint(Color("UMDRed"))
                            .frame(maxWidth: .infinity)

                            Button {
                                tabRouter.selectedTab = .collection
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
                            Button("Open Leaderboard") {
                                tabRouter.selectedTab = .map
                            }
                            .font(.caption)
                        }

                        ForEach(Array(topThree.enumerated()), id: \.element.id) { index, user in
                            HStack(spacing: 12) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(Color(hex: user.avatarColorHex).opacity(0.85))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: user.avatarType.symbolName)
                                                .foregroundStyle(.white)
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
                                        Text(user.displayName)
                                            .font(.subheadline.weight(.medium))
                                    }

                                    Text("\(user.collectedCount) collected • \(user.totalPoints) pts")
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
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(radius: 4)

                    // Stats
                    HStack(spacing: 12) {
                        StatChip(title: "Events", value: "90+", color: Color("UMDRed"))
                        StatChip(title: "Collectibles", value: "\(modelController.currentUser?.collectedCount ?? 0)", color: Color("UMDGold"))
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
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}
