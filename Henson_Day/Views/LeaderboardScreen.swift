// LeaderboardScreen.swift
// Henson_Day
//
// File Description: Top 10 players ranked by total points, backed by GET /leaderboard.
// The top 3 render as a podium with height-coded bars; ranks 4+ line up in a
// plain vertical list below.

import SwiftUI

struct LeaderboardScreen: View {
    @EnvironmentObject private var appSession: AppSession

    private var topThree: [LeaderboardEntry] {
        appSession.leaderboard.filter { $0.rank <= 3 }.sorted { $0.rank < $1.rank }
    }

    private var restOfBoard: [LeaderboardEntry] {
        appSession.leaderboard.filter { $0.rank > 3 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScreenHeaderBanner(title: "Leaderboard")

                    AlternatingDotsDivider()

                    if appSession.isLoadingLeaderboard && appSession.leaderboard.isEmpty {
                        Spacer()
                        ProgressView("Loading leaderboard…")
                        Spacer()
                    } else if appSession.leaderboard.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No rankings yet",
                            systemImage: "trophy",
                            description: Text("Collect a Terp to appear on the leaderboard.")
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: DS.Spacing.section) {
                                if !topThree.isEmpty {
                                    PodiumView(topThree: topThree)
                                }

                                VStack(spacing: DS.Spacing.card) {
                                    ForEach(restOfBoard) { entry in
                                        LeaderboardRow(entry: entry)
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.screenH)

                                AlternatingDotsDivider()
                            }
                            .padding(.top, DS.Spacing.card)
                            .padding(.bottom, DS.Spacing.section)
                        }
                        .refreshable {
                            await appSession.loadLeaderboard()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            if appSession.leaderboard.isEmpty {
                await appSession.loadLeaderboard()
            }
        }
    }
}

// MARK: - Podium

private struct PodiumView: View {
    let topThree: [LeaderboardEntry]

    private var first: LeaderboardEntry? { topThree.first { $0.rank == 1 } }
    private var second: LeaderboardEntry? { topThree.first { $0.rank == 2 } }
    private var third: LeaderboardEntry? { topThree.first { $0.rank == 3 } }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let second {
                PodiumColumn(
                    entry: second,
                    barHeight: 88,
                    barFill: AnyShapeStyle(DS.Color.heroGradient),
                    isChampion: false
                )
            }
            if let first {
                PodiumColumn(
                    entry: first,
                    barHeight: 124,
                    barFill: AnyShapeStyle(DS.Color.goldGradient),
                    isChampion: true
                )
            }
            if let third {
                PodiumColumn(
                    entry: third,
                    barHeight: 66,
                    barFill: AnyShapeStyle(
                        LinearGradient(colors: [DS.Color.statusInProgress, DS.Color.gold], startPoint: .top, endPoint: .bottom)
                    ),
                    isChampion: false
                )
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }
}

private struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let barHeight: CGFloat
    let barFill: AnyShapeStyle
    let isChampion: Bool

    private var initial: String {
        entry.fullName.first.map(String.init)?.uppercased() ?? "?"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DS.Color.gold)
                .opacity(isChampion ? 1 : 0)

            ZStack {
                Circle()
                    .fill(DS.Color.surfaceElevated)
                    .frame(width: isChampion ? 64 : 52, height: isChampion ? 64 : 52)
                Text(initial)
                    .font(.system(size: isChampion ? 24 : 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(DS.Color.campusNight)
            }
            .overlay(
                Circle().stroke(barFill, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

            VStack(spacing: 1) {
                Text(entry.fullName.isEmpty ? "Player \(entry.rank)" : entry.fullName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.campusNight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(entry.totalPoints) pts")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Color.neutral)
            }
            .frame(maxWidth: 90)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(barFill)
                Text("\(entry.rank)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .padding(.top, 10)
            }
            .frame(height: barHeight)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rows (ranks 4+)

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            ZStack {
                Circle()
                    .fill(DS.Color.primaryTint)
                    .frame(width: 40, height: 40)
                Text("\(entry.rank)")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fullName.isEmpty ? "Player \(entry.rank)" : entry.fullName)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)
                Text("\(entry.eventsAttended) events attended")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.totalPoints)")
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.primary)
                Text("points")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }
        }
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

#Preview {
    LeaderboardScreen()
        .environmentObject(AppSession(authManager: AuthManager()))
}
