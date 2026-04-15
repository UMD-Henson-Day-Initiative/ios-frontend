// LeaderboardScreen.swift
// Henson_Day

import SwiftUI

struct LeaderboardScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var filter: Filter = .all
    @State private var selectedUser: PlayerEntity?
    @State private var profileUser: PlayerEntity?
    @Namespace private var filterNS

    enum Filter: CaseIterable {
        case all, friends, club
        var label: String {
            switch self {
            case .all:     return "All Campus"
            case .friends: return "Friends"
            case .club:    return "Club"
            }
        }
        var icon: String {
            switch self {
            case .all:     return "person.3.fill"
            case .friends: return "star.fill"
            case .club:    return "trophy.fill"
            }
        }
    }

    var displayedUsers: [PlayerEntity] {
        modelController.leaderboardUsers.sorted { $0.totalPoints > $1.totalPoints }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Filter.allCases, id: \.label) { f in
                                    LeaderboardFilterChip(
                                        filter: f,
                                        current: $filter,
                                        namespace: filterNS
                                    )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.screenH)
                            .padding(.vertical, 4)
                        }

                        // Podium
                        if displayedUsers.count >= 3 {
                            TopThreePodium(users: Array(displayedUsers.prefix(3)))
                                .padding(.horizontal, DS.Spacing.screenH)
                        }

                        // Full list
                        VStack(spacing: DS.Spacing.card) {
                            ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { index, user in
                                LeaderboardRow(rank: index + 1, user: user)
                                    .onTapGesture { selectedUser = user }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.screenH)
                        .padding(.bottom, DS.Spacing.section)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileToolbarButton()
                }
            }
            .sheet(item: $selectedUser) { user in
                LeaderboardUserPopup(
                    user: user,
                    rank: (displayedUsers.firstIndex(where: { $0.id == user.id }) ?? 0) + 1,
                    onOpenProfile: {
                        selectedUser = nil
                        profileUser = user
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(item: $profileUser) { user in
                PublicProfileView(user: user, rank: (displayedUsers.firstIndex(where: { $0.id == user.id }) ?? 0) + 1)
            }
        }
    }
}

// MARK: - Filter chip

struct LeaderboardFilterChip: View {
    let filter: LeaderboardScreen.Filter
    @Binding var current: LeaderboardScreen.Filter
    let namespace: Namespace.ID

    private var isSelected: Bool { current == filter }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                current = filter
            }
        } label: {
            Label(filter.label, systemImage: filter.icon)
                .font(DS.Typography.label)
                .foregroundStyle(isSelected ? .white : DS.Color.neutral)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(DS.Color.primary)
                            .matchedGeometryEffect(id: "filterChip", in: namespace)
                    } else {
                        Capsule()
                            .fill(DS.Color.surfaceElevated)
                            .overlay(Capsule().strokeBorder(Color(UIColor.separator).opacity(0.4)))
                    }
                }
        }
    }
}

// MARK: - Podium

struct TopThreePodium: View {
    let users: [PlayerEntity]
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // 2nd place
            if users.count > 1 {
                PodiumSlot(place: 2, user: users[1], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
            }
            // 1st place (center, tallest, appears last)
            if users.count > 0 {
                PodiumSlot(place: 1, user: users[0], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: appeared)
            }
            // 3rd place
            if users.count > 2 {
                PodiumSlot(place: 3, user: users[2], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.0), value: appeared)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

struct PodiumSlot: View {
    let place: Int
    let user: PlayerEntity
    let appeared: Bool

    private var columnHeight: CGFloat {
        switch place {
        case 1: return 100
        case 2: return 78
        case 3: return 60
        default: return 60
        }
    }

    private var columnColor: Color {
        switch place {
        case 1: return DS.Color.gold
        case 2: return Color(red: 192/255, green: 192/255, blue: 192/255)  // silver
        case 3: return Color(red: 205/255, green: 127/255, blue: 50/255)   // bronze
        default: return DS.Color.neutral
        }
    }

    private var avatarSize: CGFloat { place == 1 ? 56 : 44 }

    var body: some View {
        VStack(spacing: 6) {
            // Avatar
            Image(systemName: user.avatarType.symbolName)
                .font(.system(size: place == 1 ? 22 : 16))
                .foregroundStyle(.white)
                .frame(width: avatarSize, height: avatarSize)
                .background(Color(hex: user.avatarColorHex))
                .clipShape(RoundedRectangle(cornerRadius: avatarSize * 0.28))
                .shadow(color: columnColor.opacity(0.3), radius: 6, x: 0, y: 3)

            Text(user.displayName.split(separator: " ").first.map(String.init) ?? user.displayName)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.campusNight)
                .lineLimit(1)

            Text("\(user.totalPoints) pts")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)

            // Podium column
            RoundedRectangle(cornerRadius: 10)
                .fill(columnColor.opacity(0.9))
                .frame(width: place == 1 ? 72 : 60, height: appeared ? columnHeight : 0)
                .overlay(alignment: .center) {
                    Text(place == 1 ? "🥇" : place == 2 ? "🥈" : "🥉")
                        .font(.title3)
                }
        }
    }
}

// MARK: - Row

struct LeaderboardRow: View {
    let rank: Int
    let user: PlayerEntity

    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator
            Group {
                if rank <= 3 {
                    Text("\(rank)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(DS.Color.primary)
                        .clipShape(Circle())
                } else {
                    Text("#\(rank)")
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Color.neutral)
                        .frame(width: 28, alignment: .leading)
                }
            }

            // Avatar
            Image(systemName: user.avatarType.symbolName)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: user.avatarColorHex))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(user.displayName)
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.campusNight)
                    if user.isLocalUser {
                        Text("you")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Color.primaryTint)
                            .clipShape(Capsule())
                    }
                }
                Text("\(user.collectedCount) collectibles · \(user.totalPoints) pts")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.neutral.opacity(0.5))
        }
        .padding(DS.Spacing.cardPad)
        .background(user.isLocalUser ? DS.Color.primaryTint : DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

// MARK: - Color(hex:) helper (file-private)

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
    LeaderboardScreen()
        .environmentObject(ModelController())
}
