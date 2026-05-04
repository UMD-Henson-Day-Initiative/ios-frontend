// LeaderboardScreen.swift
// Henson_Day
//
// File Description: This file defines the LeaderboardScreen, which displays a ranked list of
// players sorted by total points. It includes a filter chip row for switching between All Campus,
// Friends, and Club views, a top three podium display, and a full scrollable ranked list.

import SwiftUI

// MARK: - Theme Colors (matches CollectiblesScreen CT palette)

private enum LT {
    static let hensRed         = Color(red: 0.85, green: 0.15, blue: 0.15)
    static let hensRedSoft     = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let hensYellow      = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let hensYellowSoft  = Color(red: 1.00, green: 0.93, blue: 0.55)
    static let hensCream       = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let hensWarm        = Color(red: 0.99, green: 0.94, blue: 0.82)
    static let hensMid         = Color(red: 0.97, green: 0.88, blue: 0.72)
    static let hensDimText     = Color(red: 0.65, green: 0.30, blue: 0.25)
    static let hensFadedText   = Color(red: 0.75, green: 0.45, blue: 0.35)
    static let hensBackground  = Color(red: 1.00, green: 1.00, blue: 1.00)
}

// MARK: - Leaderboard Screen

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
                LT.hensBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Festive banner header
                        LeaderboardFestiveBannerView(playerCount: displayedUsers.count)
                            .ignoresSafeArea(edges: .top)

                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Filter.allCases, id: \.label) { f in
                                    LeaderboardFilterChipView(
                                        filter: f,
                                        current: $filter,
                                        namespace: filterNS
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(LT.hensBackground)

                        // Podium
                        if displayedUsers.count >= 3 {
                            LeaderboardPodiumView(users: Array(displayedUsers.prefix(3)))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }

                        // Section label for full list
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundStyle(LT.hensRed)
                            Text("All Rankings")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(LT.hensRed)
                            Spacer()
                            Text("\(displayedUsers.count) players")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(LT.hensDimText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(LT.hensYellowSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(LT.hensYellow, lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 16)

                        // Full list
                        VStack(spacing: 8) {
                            ForEach(Array(displayedUsers.enumerated()), id: \.element.id) { index, user in
                                LeaderboardRowView(rank: index + 1, user: user)
                                    .onTapGesture { selectedUser = user }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        LeaderboardConfettiFooterView()
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
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

// MARK: - Festive Banner

private struct LeaderboardFestiveBannerView: View {
    let playerCount: Int

    var body: some View {
        VStack(spacing: 0) {
            LeaderboardBuntingView()

            LeaderboardPennantTitleView(title: "Leaderboard")
                .padding(.top, 8)

            HStack(spacing: 10) {
                LeaderboardStatChip(label: "Players",  value: "\(playerCount)")
                LeaderboardStatChip(label: "Season",   value: "Week 1")
                LeaderboardStatChip(label: "Prize",    value: "🏆 Glory")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }
}

private struct LeaderboardBuntingView: View {
    private let flagCount = 8
    private let flagColors: [Color] = [
        LT.hensRed, LT.hensYellow, LT.hensRedSoft, LT.hensYellowSoft,
        LT.hensRed, LT.hensYellow, LT.hensRedSoft, LT.hensYellowSoft
    ]

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(flagCount)
            let ropeY: CGFloat = 18

            var rope = Path()
            rope.move(to: CGPoint(x: 0, y: ropeY))
            rope.addLine(to: CGPoint(x: size.width, y: ropeY))
            context.stroke(rope, with: .color(LT.hensYellow.opacity(0.9)), lineWidth: 1.5)

            for i in 0..<flagCount {
                let cx = CGFloat(i) * spacing + spacing / 2
                let topLeft  = CGPoint(x: cx - spacing * 0.38, y: ropeY)
                let topRight = CGPoint(x: cx + spacing * 0.38, y: ropeY)
                let tip      = CGPoint(x: cx, y: ropeY + 38)

                var flag = Path()
                flag.move(to: topLeft)
                flag.addLine(to: topRight)
                flag.addLine(to: tip)
                flag.closeSubpath()

                let color = flagColors[i % flagColors.count]
                context.fill(flag, with: .color(color.opacity(0.92)))
                context.stroke(flag, with: .color(LT.hensYellow.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 60)
        .background(LT.hensRed.opacity(0.85))
    }
}

private struct LeaderboardPennantTitleView: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(LT.hensYellow)

            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { _ in
                    Circle()
                        .fill(LT.hensYellowSoft.opacity(0.80))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 32)
        .background(LT.hensRed.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LT.hensYellow, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

private struct LeaderboardStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(LT.hensDimText)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(LT.hensRed)
        }
        .frame(maxWidth: 110)
        .padding(.vertical, 8)
        .background(LT.hensCream)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(LT.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Filter Chip

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
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? LT.hensRed : LT.hensDimText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(LT.hensYellow)
                            .overlay(Capsule().strokeBorder(LT.hensRed.opacity(0.3), lineWidth: 1.2))
                            .matchedGeometryEffect(id: "filterChip", in: namespace)
                    } else {
                        Capsule()
                            .fill(LT.hensWarm)
                            .overlay(Capsule().strokeBorder(LT.hensYellow.opacity(0.7), lineWidth: 1.2))
                    }
                }
        }
    }
}

// Typealiased to satisfy internal call sites
private typealias LeaderboardFilterChipView = LeaderboardFilterChip

// MARK: - Podium

struct TopThreePodium: View {
    let users: [PlayerEntity]
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            if users.count > 1 {
                LeaderboardPodiumSlot(place: 2, user: users[1], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
            }
            if users.count > 0 {
                LeaderboardPodiumSlot(place: 1, user: users[0], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: appeared)
            }
            if users.count > 2 {
                LeaderboardPodiumSlot(place: 3, user: users[2], appeared: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.0), value: appeared)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding()
        .background(LT.hensWarm)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LT.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(16)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// Internal alias
private typealias LeaderboardPodiumView = TopThreePodium

struct PodiumSlot: View {
    let place: Int
    let user: PlayerEntity
    let appeared: Bool

    private var columnHeight: CGFloat {
        switch place {
        case 1: return 90
        case 2: return 70
        case 3: return 55
        default: return 55
        }
    }

    private var columnColor: Color {
        switch place {
        case 1: return LT.hensYellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return LT.hensMid
        }
    }

    private var avatarSize: CGFloat { place == 1 ? 56 : 44 }

    var body: some View {
        VStack(spacing: 6) {
            // Crown for 1st
            if place == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(LT.hensYellow)
                    .shadow(color: LT.hensYellow.opacity(0.5), radius: 4)
            }

            // Avatar circle
            ZStack {
                Circle()
                    .fill(Color(hex: user.avatarColorHex).opacity(0.85))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(Circle().strokeBorder(columnColor, lineWidth: 2))
                Image(systemName: user.avatarType.symbolName)
                    .font(.system(size: place == 1 ? 22 : 16))
                    .foregroundStyle(.white)
            }
            .shadow(color: columnColor.opacity(0.4), radius: 6, x: 0, y: 3)

            Text(user.displayName.split(separator: " ").first.map(String.init) ?? user.displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(LT.hensRed)
                .lineLimit(1)

            Text("\(user.totalPoints) pts")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(LT.hensDimText)

            // Podium column
            RoundedRectangle(cornerRadius: 8)
                .fill(columnColor.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(columnColor, lineWidth: 1.5))
                .frame(width: place == 1 ? 68 : 56, height: appeared ? columnHeight : 0)
                .overlay(alignment: .center) {
                    Text(place == 1 ? "🥇" : place == 2 ? "🥈" : "🥉")
                        .font(.title3)
                }
        }
    }
}

// Internal alias
private typealias LeaderboardPodiumSlot = PodiumSlot

// MARK: - Row

struct LeaderboardRow: View {
    let rank: Int
    let user: PlayerEntity

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            Group {
                if rank <= 3 {
                    Text("\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(rank == 1 ? LT.hensRed : LT.hensCream)
                        .frame(width: 28, height: 28)
                        .background(rank == 1 ? LT.hensYellow : LT.hensRed)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(LT.hensYellow, lineWidth: rank == 1 ? 2 : 0))
                } else {
                    Text("#\(rank)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(LT.hensDimText)
                        .frame(width: 28, alignment: .leading)
                }
            }

            // Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: user.avatarColorHex).opacity(0.85))
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(LT.hensYellow.opacity(0.6), lineWidth: 1.2))
                Image(systemName: user.avatarType.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(user.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(LT.hensRed)
                    if user.isLocalUser {
                        Text("you")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(LT.hensRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LT.hensYellow)
                            .clipShape(Capsule())
                    }
                }
                Text("\(user.collectedCount) collectibles · \(user.totalPoints) pts")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(LT.hensDimText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LT.hensFadedText.opacity(0.5))
        }
        .padding(12)
        .background(user.isLocalUser ? LT.hensYellowSoft.opacity(0.5) : LT.hensWarm)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(user.isLocalUser ? LT.hensRed : LT.hensYellow, lineWidth: user.isLocalUser ? 2 : 1.2)
        )
        .cornerRadius(12)
    }
}

// Internal alias
private typealias LeaderboardRowView = LeaderboardRow

// MARK: - Confetti Footer

private struct LeaderboardConfettiFooterView: View {
    private let dots: [Color] = [
        LT.hensRed, LT.hensYellow, LT.hensRedSoft, LT.hensYellowSoft,
        LT.hensRed, LT.hensYellow, LT.hensRedSoft, LT.hensYellowSoft,
        LT.hensRed, LT.hensYellow, LT.hensRedSoft, LT.hensYellowSoft
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<dots.count, id: \.self) { i in
                Circle()
                    .fill(dots[i].opacity(0.65))
                    .frame(width: 8, height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
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
    LeaderboardScreen()
        .environmentObject(ModelController())
}
