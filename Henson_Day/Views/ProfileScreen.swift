// ProfileScreen.swift

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var appState: AppState

    private var user: User? { appState.currentUser }

    private var obtainedCount: Int {
        appState.collectibles.filter { $0.obtained }.count
    }

    private var unlockedBadges: Int {
        appState.badges.filter { $0.unlocked }.count
    }

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
                            // TODO: settings action
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)

                    // User header card
                    if let user {
                        ProfileHeaderCard(
                            user: user,
                            collectiblesCount: obtainedCount,
                            badgesCount: unlockedBadges
                        )
                        .padding(.horizontal)
                    }

                    // Quick actions
                    HStack(spacing: 12) {
                        NavigationLink {
                            LeaderboardScreen()
                        } label: {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(Color("UMDGold"))
                                Text("Leaderboard")
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Button {
                            // TODO: share profile / stats
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color("UMDRed"))
                                Text("Share")
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
                                valueLabel: "\(user?.eventsVisited ?? 0) / 15 goal",
                                progress: 0.6 // placeholder; compute from real goal if you have it
                            )
                            ProgressTile(
                                icon: "sparkles",
                                iconColor: Color("UMDGold"),
                                title: "Collection Progress",
                                valueLabel: "\(obtainedCount) / \(appState.collectibles.count)",
                                progress: appState.collectibles.isEmpty
                                    ? 0
                                    : Double(obtainedCount) / Double(appState.collectibles.count)
                            )
                            ProgressTile(
                                icon: "trophy.fill",
                                iconColor: .orange,
                                title: "Badges Unlocked",
                                valueLabel: "\(unlockedBadges) / \(appState.badges.count)",
                                progress: appState.badges.isEmpty
                                    ? 0
                                    : Double(unlockedBadges) / Double(appState.badges.count)
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
    let user: User
    let collectiblesCount: Int
    let badgesCount: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Text(user.avatarEmoji)
                    .font(.system(size: 40))
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(
                            colors: [Color("UMDRed"), Color("UMDGold")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.white, lineWidth: 3)
                    )
                    .shadow(radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.title3.weight(.semibold))
                    Text("Henson Week Explorer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(user.score)")
                                .font(.headline)
                                .foregroundStyle(Color("UMDRed"))
                            Text("Total Points")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#4") // placeholder rank; wire to leaderboard if you have it
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
                ProfileStatPill(title: "Events", value: "\(user.eventsVisited)")
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
            // TODO: hook up action
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
}
