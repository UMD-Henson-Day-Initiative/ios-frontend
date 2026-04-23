//  HomeScreen.swift
//  Henson_Day

import SwiftUI

// MARK: - Home Screen

struct HomeScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    var topThree: [PlayerEntity] {
        Array(modelController.leaderboardUsers.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Featured Event Card (now at top, replaces hero banner)
                    FeaturedEventCardView(
                        week: 1,
                        day: 3,
                        title: "McKeldin Time Capsule Hunt",
                        timeRange: "2:30 – 4:00 PM",
                        location: "McKeldin Mall",
                        onViewEvent: {
                            tabRouter.selectedTab = .map
                        }
                    )

                    // Description
                    Text("Join the AR scavenger hunt across UMD. Tap the Map icon to find events and AR characters. Collect creatures, earn points, and climb the leaderboard!")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Top Collectors
                    TopCollectorsView(topThree: topThree, tabRouter: tabRouter)

                    // Stats
                    HStack(spacing: 12) {
                        StatChip(title: "Events",       value: "90+",                                                color: Color("UMDRed"))
                        StatChip(title: "Collectibles", value: "\(modelController.currentUser?.collectedCount ?? 0)", color: Color("UMDGold"))
                        StatChip(title: "Days",         value: "7",                                                  color: .orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Henson Week")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Featured Event Card

private struct FeaturedEventCardView: View {
    let week: Int
    let day: Int
    let title: String
    let timeRange: String
    let location: String
    let onViewEvent: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color("UMDRed"))

                // Soft circle accent top-right
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 180, height: 180)
                    .offset(x: geo.size.width - 70, y: -55)

                // Content
                VStack(alignment: .leading, spacing: 14) {

                    // WEEK · DAY pill
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .black))
                        Text("WEEK \(week) · DAY \(day)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(0.4)
                    }
                    .foregroundStyle(Color("UMDRed"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("UMDGold"))
                    .clipShape(Capsule())

                    // Title
                    Text(title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(1)

                    // Time & Location
                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(timeRange)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                                .fixedSize()
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(location)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }

                    // CTA Button
                    Button(action: onViewEvent) {
                        HStack(spacing: 6) {
                            Text("View event")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color("UMDRed").opacity(0.4), radius: 14, x: 0, y: 7)
        }
        .frame(height: 210)
    }
}

// MARK: - Top Collectors

private struct TopCollectorsView: View {
    let topThree: [PlayerEntity]
    let tabRouter: TabRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top 3 Collectors")
                    .font(.headline)
                Spacer()
                Button("Open Leaderboard") {
                    tabRouter.selectedTab = .map
                }
                .font(.caption)
            }

            ForEach(Array(topThree.enumerated()), id: \.element.id) { index, user in
                HStack(spacing: 12) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(hex: user.avatarColorHex).opacity(0.85))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: user.avatarType.symbolName)
                                    .foregroundStyle(.white)
                            )

                        if index == 0 {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color("UMDRed"))
                                .padding(4)
                                .background(Color("UMDGold"))
                                .clipShape(Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(user.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                        Text("\(user.collectedCount) collected • \(user.totalPoints) pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉")
                        .font(.title3)
                }
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 4)
    }
}

// MARK: - Preview

#Preview {
    HomeScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}

// MARK: - Color + Hex

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
