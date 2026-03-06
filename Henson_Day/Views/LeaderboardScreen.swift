// LeaderboardScreen.swift
// Henson_Day

import SwiftUI

struct LeaderboardScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var filter: Filter = .all

    enum Filter {
        case all, friends, club
    }

    var displayedUsers: [LeaderboardUser] {
        // For now, ignore filter and just sort by score
        appState.leaderboardUsers.sorted { $0.score > $1.score }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Filters
                    HStack(spacing: 8) {
                        LeaderboardFilterChip(
                            title: "All Campus",
                            systemName: "person.3.fill",
                            filter: .all,
                            current: $filter
                        )
                        LeaderboardFilterChip(
                            title: "Friends",
                            systemName: "star.fill",
                            filter: .friends,
                            current: $filter
                        )
                        LeaderboardFilterChip(
                            title: "Club",
                            systemName: "trophy.fill",
                            filter: .club,
                            current: $filter
                        )
                    }
                    .padding(.horizontal)

                    // Podium
                    if displayedUsers.count >= 3 {
                        TopThreePodium(users: Array(displayedUsers.prefix(3)))
                    }

                    // Full list
                    VStack(spacing: 8) {
                        ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { (index, user) in
                            LeaderboardRow(rank: index + 1, user: user)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Leaderboard")
        }
    }
}

// MARK: - Filter chip

struct LeaderboardFilterChip: View {
    let title: String
    let systemName: String
    let filter: LeaderboardScreen.Filter
    @Binding var current: LeaderboardScreen.Filter

    var body: some View {
        Button {
            current = filter
        } label: {
            Label(title, systemImage: systemName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(current == filter ? Color("UMDRed") : Color(.systemBackground))
                .foregroundStyle(current == filter ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct TopThreePodium: View {
    let users: [LeaderboardUser]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if users.count > 1 {
                PodiumSlot(place: 2, user: users[1])
            }
            if users.count > 0 {
                PodiumSlot(place: 1, user: users[0])
            }
            if users.count > 2 {
                PodiumSlot(place: 3, user: users[2])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct PodiumSlot: View {
    let place: Int
    let user: LeaderboardUser

    private var columnHeight: CGFloat {
        switch place {
        case 1: return 80
        case 2: return 60
        case 3: return 40
        default: return 40
        }
    }

    private var color: Color {
        switch place {
        case 1: return Color("UMDGold")
        case 2: return .gray
        case 3: return .orange
        default: return .gray
        }
    }

    private var medal: String {
        switch place {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(user.avatarEmoji)
                .font(place == 1 ? .system(size: 40) : .system(size: 34))
                .frame(width: 64, height: 64)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 4)

            Text(user.name.split(separator: " ").first.map(String.init) ?? user.name)
                .font(.caption)
                .lineLimit(1)

            Text("\(user.score) pts")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.9))
                    .frame(width: 60, height: columnHeight)
                Text(medal)
                    .font(.title3)
            }
        }
    }
}

// MARK: - Row for full list

struct LeaderboardRow: View {
    let rank: Int
    let user: LeaderboardUser

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            if rank <= 3 {
                Text(rank == 1 ? "🥇" : rank == 2 ? "🥈" : "🥉")
                    .font(.title3)
                    .frame(width: 32)
            } else {
                Text("#\(rank)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
            }

            // Avatar
            Text(user.avatarEmoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color("UMDRed").opacity(0.2),
                                         Color("UMDGold").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.name)
                        .font(.subheadline.weight(.medium))
                    if user.isCurrentUser {
                        Text("(You)")
                            .font(.caption2)
                            .foregroundStyle(Color("UMDRed"))
                    }
                }
                Text("\(user.eventsVisited) events • \(user.score) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 1)
    }
}

#Preview {
    LeaderboardScreen()
        .environmentObject(AppState())
}
