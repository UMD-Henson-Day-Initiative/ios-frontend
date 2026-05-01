// ProfileScreen.swift
// Henson_Day

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var authController: AuthController
    @State private var progressAppeared = false
    @State private var showSignOutAlert = false

    private var snapshot: UserProfileSnapshot {
        UserDatabase.profileSnapshot(from: modelController)
    }

    private let avatarColors = ["#D7263D", "#2D7FF9", "#22C55E", "#F59E0B", "#A855F7", "#14B8A6"]
    private let unlockedBadges = 3

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.section) {
                        // Avatar section
                        AvatarSection(
                            snapshot: snapshot,
                            modelController: modelController,
                            avatarColors: avatarColors
                        )

                        // Stats card
                        StatsCard(
                            snapshot: snapshot,
                            collectiblesTotal: modelController.collectibleCatalog.count,
                            badgesCount: unlockedBadges
                        )
                        .padding(.horizontal, DS.Spacing.screenH)

                        // Week progress
                        VStack(alignment: .leading, spacing: DS.Spacing.card) {
                            Text("This Week")
                                .font(DS.Typography.title2)
                                .foregroundStyle(DS.Color.campusNight)

                            AnimatedProgressRow(
                                icon: "mappin.and.ellipse",
                                iconColor: DS.Color.primary,
                                title: "Events Attended",
                                value: max(snapshot.collectedCount * 2, 1),
                                total: 15,
                                fillColor: DS.Color.primary,
                                appeared: progressAppeared
                            )
                            AnimatedProgressRow(
                                icon: "sparkles",
                                iconColor: DS.Color.gold,
                                title: "Collectibles",
                                value: snapshot.collectedCount,
                                total: max(modelController.collectibleCatalog.count, 1),
                                fillColor: DS.Color.gold,
                                appeared: progressAppeared
                            )
                            AnimatedProgressRow(
                                icon: "trophy.fill",
                                iconColor: DS.Color.statusCompleted,
                                title: "Badges Unlocked",
                                value: unlockedBadges,
                                total: 3,
                                fillColor: DS.Color.statusCompleted,
                                appeared: progressAppeared
                            )
                        }
                        .padding(.horizontal, DS.Spacing.screenH)

                        // Quick actions
                        HStack(spacing: DS.Spacing.card) {
                            SecondaryPillButton(title: "Go to Map", icon: "map.fill") {
                                tabRouter.selectedTab = .map
                            }
                            SecondaryPillButton(title: "Schedule", icon: "calendar") {
                                tabRouter.selectedTab = .schedule
                            }
                        }
                        .padding(.horizontal, DS.Spacing.screenH)

                        // Sign out
                        Button {
                            showSignOutAlert = true
                        } label: {
                            Text("Sign out")
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.neutral)
                        }
                        .padding(.bottom, DS.Spacing.section)
                    }
                    .padding(.top, DS.Spacing.card)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(.spring(duration: 0.8).delay(0.2)) {
                    progressAppeared = true
                }
            }
            .alert("Sign out of HensonDay?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await authController.signOut() }
                }
            }
        }
    }
}

// MARK: - Avatar section

private struct AvatarSection: View {
    let snapshot: UserProfileSnapshot
    let modelController: ModelController
    let avatarColors: [String]

    private var avatarColorHex: String {
        modelController.currentUser?.avatarColorHex ?? "#D7263D"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Avatar tile
            Image(systemName: modelController.currentUser?.avatarType.symbolName ?? "person.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Color(hex: avatarColorHex))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: Color(hex: avatarColorHex).opacity(0.35), radius: 10, x: 0, y: 4)

            Text(snapshot.displayName)
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.campusNight)

            Text("Henson Week Explorer")
                .font(DS.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(DS.Color.primary)
                .clipShape(Capsule())

            // Character selector strips
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AvatarType.allCases, id: \.self) { avatar in
                            Button {
                                modelController.updateCurrentUserAvatar(
                                    type: avatar,
                                    colorHex: avatarColorHex
                                )
                            } label: {
                                Image(systemName: avatar.symbolName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: avatarColorHex))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().strokeBorder(
                                            modelController.currentUser?.avatarType == avatar ? DS.Color.primary : .clear,
                                            lineWidth: 2.5
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(avatarColors, id: \.self) { hex in
                        Button {
                            modelController.updateCurrentUserAvatar(
                                type: modelController.currentUser?.avatarType ?? .turtle,
                                colorHex: hex
                            )
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle().strokeBorder(
                                        avatarColorHex.lowercased() == hex.lowercased() ? DS.Color.campusNight : .clear,
                                        lineWidth: 2
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
    }
}

// MARK: - Stats card

private struct StatsCard: View {
    let snapshot: UserProfileSnapshot
    let collectiblesTotal: Int
    let badgesCount: Int

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(snapshot.totalPoints)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(DS.Color.gold)
                    Text("Total Points")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.campusNight.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("#\(max(snapshot.rank, 1))")
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.campusNight)
                    Text("Campus Rank")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.campusNight.opacity(0.6))
                }
            }

            Divider().overlay(Color.white.opacity(0.3))

            HStack {
                StatsCardPill(title: "Events",     value: "\(max(snapshot.collectedCount * 2, 1))")
                StatsCardPill(title: "Collectibles", value: "\(snapshot.collectedCount)")
                StatsCardPill(title: "Badges",     value: "\(badgesCount)")
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
    }
}

private struct StatsCardPill: View {
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

// MARK: - Animated progress row

private struct AnimatedProgressRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: Int
    let total: Int
    let fillColor: Color
    let appeared: Bool

    private var progress: Double {
        total > 0 ? min(Double(value) / Double(total), 1.0) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.campusNight)
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text("\(value) / \(total)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillColor)
                        .frame(width: appeared ? geo.size.width * progress : 0, height: 6)
                        .animation(.spring(duration: 0.8), value: appeared)
                }
            }
            .frame(height: 6)
        }
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

// MARK: - Secondary pill button

private struct SecondaryPillButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Color.campusNight)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(Capsule())
        }
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

#Preview {
    ProfileScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
    .environmentObject(AuthController())
}

// MARK: - Profile toolbar button (shared across all screens)

struct ProfileToolbarButton: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            if let user = modelController.currentUser {
                Image(systemName: user.avatarType.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: user.avatarColorHex))
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.primary)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileScreen()
                .environmentObject(modelController)
                .environmentObject(tabRouter)
        }
    }
}

// Local Color(hex:) helper for ProfileToolbarButton is provided by the existing
// extension defined later in this file.
