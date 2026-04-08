// ProfileScreen.swift

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    private var snapshot: UserProfileSnapshot {
        UserDatabase.profileSnapshot(from: modelController)
    }

    private var unlockedBadges: Int { 3 }

    private let avatarColors = ["#D7263D", "#2D7FF9", "#22C55E", "#F59E0B", "#A855F7", "#14B8A6"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Title row
                    HStack {
                        Text("Profile")
                            .font(.largeTitle.bold())
                        Spacer()
                        Button {
                            tabRouter.selectedTab = .profile
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Customize Avatar")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(AvatarType.allCases, id: \.self) { avatar in
                                    Button {
                                        modelController.updateCurrentUserAvatar(
                                            type: avatar,
                                            colorHex: modelController.currentUser?.avatarColorHex ?? "#D7263D"
                                        )
                                    } label: {
                                        Image(systemName: avatar.symbolName)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(width: 34, height: 34)
                                            .background(Color(hex: modelController.currentUser?.avatarColorHex ?? "#D7263D"))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            ForEach(avatarColors, id: \.self) { colorHex in
                                Button {
                                    modelController.updateCurrentUserAvatar(
                                        type: modelController.currentUser?.avatarType ?? .turtle,
                                        colorHex: colorHex
                                    )
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 24, height: 24)
                                        .overlay(Circle().stroke(.white, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // User header card
                    ProfileHeaderCard(
                        displayName: snapshot.displayName,
                        totalPoints: snapshot.totalPoints,
                        rank: snapshot.rank,
                        collectiblesCount: snapshot.collectedCount,
                        badgesCount: unlockedBadges,
                        avatarColorHex: modelController.currentUser?.avatarColorHex ?? "#D7263D",
                        avatarSymbol: modelController.currentUser?.avatarType.symbolName ?? "person.fill"
                    )
                    .padding(.horizontal)

                    // Quick actions
                    HStack(spacing: 12) {
                        Button {
                            tabRouter.selectedTab = .map
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(Color("UMDGold"))
                                Text("Go to Map")
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Button {
                            tabRouter.selectedTab = .schedule
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color("UMDRed"))
                                Text("Go to Schedule")
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .padding(.horizontal)

                    // Week progress
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Week Progress")
                            .font(.headline)

                        VStack(spacing: 10) {
                            ProgressTile(
                                icon: "mappin.and.ellipse",
                                iconColor: Color("UMDRed"),
                                title: "Events Attended",
                                valueLabel: "\(max(snapshot.collectedCount * 2, 1)) / 15 goal",
                                progress: min(Double(max(snapshot.collectedCount * 2, 1)) / 15.0, 1)
                            )
                            ProgressTile(
                                icon: "sparkles",
                                iconColor: Color("UMDGold"),
                                title: "Collection Progress",
                                valueLabel: "\(snapshot.collectedCount) / \(modelController.collectibleCatalog.count)",
                                progress: modelController.collectibleCatalog.isEmpty
                                    ? 0
                                    : Double(snapshot.collectedCount) / Double(modelController.collectibleCatalog.count)
                            )
                            ProgressTile(
                                icon: "trophy.fill",
                                iconColor: .orange,
                                title: "Badges Unlocked",
                                valueLabel: "\(unlockedBadges) / 3",
                                progress: Double(unlockedBadges) / 3.0
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Settings-ish rows
                    VStack(spacing: 8) {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .blue,
                            title: "Notifications"
                        )
                        SettingsRow(
                            icon: "gearshape.fill",
                            iconColor: .gray,
                            title: "Settings"
                        )
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: .red,
                            title: "Log Out",
                            destructive: true
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 12)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Header card

struct ProfileHeaderCard: View {
    let displayName: String
    let totalPoints: Int
    let rank: Int
    let collectiblesCount: Int
    let badgesCount: Int
    let avatarColorHex: String
    let avatarSymbol: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: avatarSymbol)
                    .font(.system(size: 30, weight: .semibold))
                    .frame(width: 72, height: 72)
                    .background(Color(hex: avatarColorHex))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white, lineWidth: 3)
                    )
                    .shadow(radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                    Text("Henson Week Explorer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(totalPoints)")
                                .font(.headline)
                                .foregroundStyle(Color("UMDRed"))
                            Text("Total Points")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(max(rank, 1))")
                                .font(.headline)
                                .foregroundStyle(Color("UMDGold"))
                            Text("Rank")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 8) {
                ProfileStatPill(title: "Events", value: "\(max(collectiblesCount * 2, 1))")
                ProfileStatPill(title: "Creatures", value: "\(collectiblesCount)")
                ProfileStatPill(title: "Badges", value: "\(badgesCount)")
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color("UMDRed").opacity(0.12),
                         Color("UMDGold").opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color("UMDRed").opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 4)
    }
}

struct ProfileStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Progress & settings rows

struct ProgressTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let valueLabel: String
    let progress: Double   // 0–1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.subheadline)
                }
                Spacer()
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(iconColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 2)
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var destructive: Bool = false
    
    var body: some View {
        Button {
            _ = title
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .foregroundStyle(destructive ? .red : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ProfileScreen()
        .environmentObject(ModelController.preview())
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
