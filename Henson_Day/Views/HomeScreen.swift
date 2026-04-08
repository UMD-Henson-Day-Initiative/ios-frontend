// HomeScreen.swift
// Henson_Day

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var heroAppeared = false
    @State private var statsAppeared = false
    @State private var cardsAppeared = false

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
                            tabRouter.selectedTab = .leaderboard
                        }
                        .padding(.horizontal, DS.Spacing.screenH)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 12)

                        // How it works
                        VStack(alignment: .leading, spacing: 14) {
                            Text("How It Works")
                                .font(DS.Typography.display)
                                .foregroundStyle(DS.Color.campusNight)
                                .padding(.horizontal, DS.Spacing.screenH)

                            VStack(spacing: DS.Spacing.card) {
                                ForEach(Array(tutorialCards.enumerated()), id: \.offset) { index, card in
                                    TutorialCard(card: card)
                                        .opacity(cardsAppeared ? 1 : 0)
                                        .offset(y: cardsAppeared ? 0 : 14)
                                        .animation(
                                            .easeOut(duration: 0.32).delay(Double(index) * 0.07),
                                            value: cardsAppeared
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileToolbarButton()
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
                    cardsAppeared = true
                }
            }
        }
    }

    private var tutorialCards: [TutorialCardModel] {
        [
            TutorialCardModel(
                icon: "calendar",
                color: DS.Color.primary,
                tint: DS.Color.primaryTint,
                title: "Schedule",
                description: "Browse all Henson Week events, see what collectibles each one offers, and plan your week."
            ),
            TutorialCardModel(
                icon: "map.fill",
                color: DS.Color.Rarity.rare,
                tint: DS.Color.Rarity.rareTint,
                title: "Map",
                description: "Explore campus, tap event pins to see what's happening nearby, and launch AR to capture muppets."
            ),
            TutorialCardModel(
                icon: "star.square.fill",
                color: DS.Color.gold,
                tint: DS.Color.Rarity.legendaryTint,
                title: "Collection",
                description: "View every muppet you've collected, check their rarity, and track how many points you've earned."
            ),
            TutorialCardModel(
                icon: "trophy.fill",
                color: DS.Color.Rarity.epic,
                tint: DS.Color.Rarity.epicTint,
                title: "Leaderboard",
                description: "See where you rank against the rest of campus across the full week."
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

// MARK: - Tutorial card

private struct TutorialCardModel {
    let icon: String
    let color: Color
    let tint: Color
    let title: String
    let description: String
}

private struct TutorialCard: View {
    let card: TutorialCardModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: card.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(card.color)
                .frame(width: 52, height: 52)
                .background(card.tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)
                Text(card.description)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

#Preview {
    HomeScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
