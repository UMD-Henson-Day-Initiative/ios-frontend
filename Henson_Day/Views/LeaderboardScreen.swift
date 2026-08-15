// LeaderboardScreen.swift
// Henson_Day
//
// File Description: Top 10 players ranked by total points, backed by GET /leaderboard.

import SwiftUI

struct LeaderboardScreen: View {
    @EnvironmentObject private var appSession: AppSession

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                if appSession.isLoadingLeaderboard && appSession.leaderboard.isEmpty {
                    ProgressView("Loading leaderboard…")
                } else if appSession.leaderboard.isEmpty {
                    ContentUnavailableView(
                        "No rankings yet",
                        systemImage: "trophy",
                        description: Text("Collect a coin to appear on the leaderboard.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.card) {
                            ForEach(appSession.leaderboard) { entry in
                                LeaderboardRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.screenH)
                        .padding(.top, DS.Spacing.section)
                        .padding(.bottom, DS.Spacing.section)
                    }
                    .refreshable {
                        await appSession.loadLeaderboard()
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            if appSession.leaderboard.isEmpty {
                await appSession.loadLeaderboard()
            }
        }
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    private var isTopThree: Bool { entry.rank <= 3 }

    private var rankColor: Color {
        switch entry.rank {
        case 1: return DS.Color.gold
        case 2: return Color(white: 0.7)
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return DS.Color.neutral
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            ZStack {
                Circle()
                    .fill(isTopThree ? rankColor.opacity(0.18) : DS.Color.primaryTint)
                    .frame(width: 40, height: 40)
                if isTopThree {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(rankColor)
                } else {
                    Text("\(entry.rank)")
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.campusNight)
                }
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
