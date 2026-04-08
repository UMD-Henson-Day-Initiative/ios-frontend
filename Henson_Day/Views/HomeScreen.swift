// HomeScreen.swift
// Henson_Day

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var heroAppeared = false
    @State private var statsAppeared = false
    @State private var gridAppeared = false

    private var nextEvent: DatabaseEvent? {
        modelController.scheduleEvents.first
    }

    private var collectedCount: Int {
        modelController.currentUser?.collectedCount ?? 0
    }

    private var totalPoints: Int {
        modelController.currentUser?.totalPoints ?? 0
    }

    private var userRank: Int {
        let sorted = modelController.leaderboardUsers.sorted { $0.totalPoints > $1.totalPoints }
        return (sorted.firstIndex { $0.isLocalUser } ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.section) {
                        // Hero stage card
                        HeroStageCard(event: nextEvent)
                            .padding(.horizontal, DS.Spacing.screenH)
                            .offset(y: heroAppeared ? 0 : 20)
                            .opacity(heroAppeared ? 1 : 0)

                        // Stat strip
                        HomeStatStrip(
                            collected: collectedCount,
                            points: totalPoints,
                            rank: userRank
                        ) {
                            tabRouter.selectedTab = .collection
                        } onLeaderboard: {
                            tabRouter.selectedTab = .profile
                        }
                        .padding(.horizontal, DS.Spacing.screenH)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 12)

                        // Explore grid
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Explore")
                                .font(DS.Typography.display)
                                .foregroundStyle(DS.Color.campusNight)
                                .padding(.horizontal, DS.Spacing.screenH)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: DS.Spacing.card), GridItem(.flexible(), spacing: DS.Spacing.card)],
                                spacing: DS.Spacing.card
                            ) {
                                ForEach(Array(navTiles.enumerated()), id: \.offset) { index, tile in
                                    NavTile(tile: tile)
                                        .onTapGesture { tile.action() }
                                        .opacity(gridAppeared ? 1 : 0)
                                        .offset(y: gridAppeared ? 0 : 16)
                                        .animation(
                                            .easeOut(duration: 0.3).delay(Double(index) * 0.06),
                                            value: gridAppeared
                                        )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screenH)
                        }
                    }
                    .padding(.top, DS.Spacing.card)
                    .padding(.bottom, DS.Spacing.section)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("HensonDay")
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.primary)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    heroAppeared = true
                }
                withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
                    statsAppeared = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.22)) {
                    gridAppeared = true
                }
            }
        }
    }

    private var navTiles: [NavTileModel] {
        [
            NavTileModel(
                title: "Schedule", icon: "calendar",
                background: DS.Color.primaryTint, accent: DS.Color.primary,
                action: { tabRouter.selectedTab = .schedule }
            ),
            NavTileModel(
                title: "Map", icon: "map.fill",
                background: Color(red: 240/255, green: 247/255, blue: 255/255),
                accent: DS.Color.Rarity.rare,
                action: { tabRouter.selectedTab = .map }
            ),
            NavTileModel(
                title: "Collection", icon: "star.square.fill",
                background: DS.Color.Rarity.legendaryTint,
                accent: DS.Color.gold,
                action: { tabRouter.selectedTab = .collection }
            ),
            NavTileModel(
                title: "Profile", icon: "person.circle.fill",
                background: DS.Color.Rarity.commonTint,
                accent: DS.Color.Rarity.common,
                action: { tabRouter.selectedTab = .profile }
            ),
        ]
    }
}

// MARK: - Hero stage card

private struct HeroStageCard: View {
    let event: DatabaseEvent?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: [DS.Color.primary, Color(red: 139/255, green: 0, blue: 0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.heroCard, style: .continuous))
            .frame(height: 200)

            // Day badge top-left
            VStack(alignment: .leading, spacing: 10) {
                Text("Henson Week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())

                if let ev = event {
                    Text(ev.title)
                        .font(DS.Typography.title1)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Label("\(ev.timeRange) · \(ev.locationName)", systemImage: "clock")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Campus comes alive this week.")
                        .font(DS.Typography.title1)
                        .foregroundStyle(.white)
                }
            }
            .padding(DS.Spacing.cardPad)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: DS.Color.primary.opacity(0.3), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Home stat strip

private struct HomeStatStrip: View {
    let collected: Int
    let points: Int
    let rank: Int
    let onCollection: () -> Void
    let onLeaderboard: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            Button(action: onCollection) {
                StatTile(value: "\(collected)", label: "Collected", icon: "star.fill")
            }
            .buttonStyle(.plain)

            StatTile(value: "\(points)", label: "Points", icon: "bolt.fill")

            Button(action: onLeaderboard) {
                StatTile(value: "#\(rank)", label: "Rank", icon: "chart.bar.fill")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Nav tile

private struct NavTileModel {
    let title: String
    let icon: String
    let background: Color
    let accent: Color
    let action: () -> Void
}

private struct NavTile: View {
    let tile: NavTileModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: tile.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(tile.accent)
            Spacer()
            Text(tile.title)
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Color.campusNight)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(DS.Spacing.cardPad)
        .background(tile.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

#Preview {
    HomeScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
