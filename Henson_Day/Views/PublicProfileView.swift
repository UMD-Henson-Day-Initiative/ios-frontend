// PublicProfileView.swift
// Henson_Day

import SwiftUI

// MARK: - Leaderboard user popup (brief detail sheet)

struct LeaderboardUserPopup: View {
    let user: PlayerEntity
    let rank: Int
    let onOpenProfile: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            Image(systemName: user.avatarType.symbolName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color(hex: user.avatarColorHex))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color(hex: user.avatarColorHex).opacity(0.3), radius: 8, x: 0, y: 4)

            // Name + rank
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.campusNight)

                Text("Rank #\(rank) · \(user.totalPoints) pts")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.neutral)
            }

            // Quick stats
            HStack(spacing: 12) {
                PopupStatPill(value: "\(user.totalPoints)", label: "Points", color: DS.Color.gold)
                PopupStatPill(value: "\(user.collectedCount)", label: "Collected", color: DS.Color.Rarity.rare)
                PopupStatPill(value: "#\(rank)", label: "Rank", color: DS.Color.primary)
            }
            .padding(.horizontal, 20)

            // Tagline
            if user.isLocalUser {
                Text("This is you!")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DS.Color.primaryTint)
                    .clipShape(Capsule())
            }

            // Open Profile button
            Button(action: {
                dismiss()
                onOpenProfile()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                    Text("View Profile")
                }
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(DS.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button > 48 ? 24 : DS.Radius.button))
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 28)
        .background(DS.Color.surface.ignoresSafeArea())
    }
}

private struct PopupStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DS.Typography.title2)
                .foregroundStyle(color)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

// MARK: - Full public profile view

struct PublicProfileView: View {
    let user: PlayerEntity
    let rank: Int

    var body: some View {
        ZStack {
            DS.Color.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.section) {
                    // Avatar hero
                    VStack(spacing: 12) {
                        Image(systemName: user.avatarType.symbolName)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                            .background(Color(hex: user.avatarColorHex))
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .shadow(color: Color(hex: user.avatarColorHex).opacity(0.3), radius: 12, x: 0, y: 6)

                        Text(user.displayName)
                            .font(DS.Typography.display)
                            .foregroundStyle(DS.Color.campusNight)

                        Text("Henson Week Explorer")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(DS.Color.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)

                    // Stats card
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(user.totalPoints)")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(DS.Color.gold)
                                Text("Total Points")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Color.campusNight.opacity(0.6))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("#\(max(rank, 1))")
                                    .font(DS.Typography.title1)
                                    .foregroundStyle(DS.Color.campusNight)
                                Text("Campus Rank")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Color.campusNight.opacity(0.6))
                            }
                        }

                        Divider()

                        HStack {
                            ProfileStatPill(title: "Collectibles", value: "\(user.collectedCount)")
                            ProfileStatPill(title: "Points", value: "\(user.totalPoints)")
                            ProfileStatPill(title: "Rank", value: "#\(rank)")
                        }
                    }
                    .padding(DS.Spacing.cardPad)
                    .background(
                        LinearGradient(
                            colors: [DS.Color.primaryTint, DS.Color.Rarity.legendaryTint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                    .shadow(color: DS.Color.primary.opacity(0.12), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, DS.Spacing.screenH)

                    // Activity section
                    VStack(alignment: .leading, spacing: DS.Spacing.card) {
                        Text("Activity")
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Color.campusNight)

                        HStack(spacing: DS.Spacing.card) {
                            StatTile(value: "\(user.collectedCount)", label: "Collected", icon: "sparkles")
                            StatTile(value: "#\(rank)", label: "Rank", icon: "trophy.fill")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.bottom, DS.Spacing.section)
                }
                .padding(.top, DS.Spacing.card)
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Color.campusNight)
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(DS.Color.surfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DS.Color.primary)

            Text(value)
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Color.campusNight)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}
// MARK: - Color(hex:) helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview("Popup") {
    LeaderboardUserPopup(
        user: PlayerEntity(displayName: "Alex M.", avatarColorHex: "#D7263D", avatarType: .turtle, totalPoints: 1450, collectedCount: 12),
        rank: 3,
        onOpenProfile: {}
    )
}

#Preview("Profile") {
    NavigationStack {
        PublicProfileView(
            user: PlayerEntity(displayName: "Alex M.", avatarColorHex: "#D7263D", avatarType: .turtle, totalPoints: 1450, collectedCount: 12),
            rank: 3
        )
    }
}
