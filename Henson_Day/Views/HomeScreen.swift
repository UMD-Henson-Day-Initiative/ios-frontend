//  HomeScreen.swift
//  Henson_Day

import SwiftUI

// MARK: - Theme Colors (matches CollectiblesScreen CT palette)

private enum HT {
    static let hensRed         = Color(red: 0.85, green: 0.15, blue: 0.15)
    static let hensRedSoft     = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let hensRedPale     = Color(red: 1.00, green: 0.88, blue: 0.88)
    static let hensYellow      = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let hensYellowSoft  = Color(red: 1.00, green: 0.93, blue: 0.55)
    static let hensCream       = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let hensWarm        = Color(red: 0.99, green: 0.94, blue: 0.82)
    static let hensMid         = Color(red: 0.97, green: 0.88, blue: 0.72)
    static let hensDimText     = Color(red: 0.65, green: 0.30, blue: 0.25)
    static let hensFadedText   = Color(red: 0.75, green: 0.45, blue: 0.35)
    static let hensBackground  = Color(red: 1.00, green: 1.00, blue: 1.00)
}

// MARK: - Home Screen

struct HomeScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    var body: some View {
        NavigationStack {
            ZStack {
                HT.hensBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // Festive banner header
                        HomeFestiveBannerView()
                            .ignoresSafeArea(edges: .top)

                        VStack(spacing: 20) {

                            // Featured Event Card
                            HomeFeaturedEventCardView(
                                week: 1,
                                day: 3,
                                title: "McKeldin Time Capsule Hunt",
                                timeRange: "2:30 – 4:00 PM",
                                location: "McKeldin Mall",
                                onViewEvent: {
                                    tabRouter.selectedTab = .map
                                }
                            )
                            .padding(.horizontal, 16)

                            // Description card
                            HomeDescriptionCardView()
                                .padding(.horizontal, 16)

                            // Stats row
                            HomeStatsRowView(modelController: modelController)
                                .padding(.horizontal, 16)

                            HomeConfettiFooterView()
                                .padding(.top, 8)
                                .padding(.bottom, 16)
                        }
                        .padding(.top, 16)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Festive Banner (matches CollectiblesScreen pattern)

private struct HomeFestiveBannerView: View {
    var body: some View {
        VStack(spacing: 0) {
            HomeBuntingView()

            HomePennantTitleView(title: "Henson Week")

            Text("University of Maryland · AR Scavenger Hunt")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(HT.hensYellowSoft.opacity(0.9))
                .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [HT.hensRed, HT.hensRed.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

private struct HomeBuntingView: View {
    private let flagCount = 8
    private let flagColors: [Color] = [
        HT.hensRed, HT.hensYellow, HT.hensRedSoft, HT.hensYellowSoft,
        HT.hensRed, HT.hensYellow, HT.hensRedSoft, HT.hensYellowSoft
    ]

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(flagCount)
            let ropeY: CGFloat = 18

            var rope = Path()
            rope.move(to: CGPoint(x: 0, y: ropeY))
            rope.addLine(to: CGPoint(x: size.width, y: ropeY))
            context.stroke(rope, with: .color(HT.hensYellow.opacity(0.9)), lineWidth: 1.5)

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
                context.stroke(flag, with: .color(HT.hensYellow.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 60)
    }
}

private struct HomePennantTitleView: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(HT.hensYellow)

            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { _ in
                    Circle()
                        .fill(HT.hensYellowSoft.opacity(0.80))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 32)
        .background(HT.hensRed.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HT.hensYellow, lineWidth: 2)
        )
        .cornerRadius(12)
        .padding(.bottom, 8)
    }
}

// MARK: - Featured Event Card

private struct HomeFeaturedEventCardView: View {
    let week: Int
    let day: Int
    let title: String
    let timeRange: String
    let location: String
    let onViewEvent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header band
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(HT.hensRed)
                    Text("WEEK \(week) · DAY \(day) · FEATURED")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(HT.hensRed)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(HT.hensYellow)
                .cornerRadius(8)

                Spacer()
            }
            .padding(14)
            .background(HT.hensRed)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(HT.hensRed)

                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(HT.hensDimText)
                        Text(timeRange)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(HT.hensDimText)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundStyle(HT.hensDimText)
                        Text(location)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(HT.hensDimText)
                    }
                }

                Button(action: onViewEvent) {
                    HStack(spacing: 6) {
                        Text("View on Map")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(HT.hensCream)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(HT.hensRed)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(HT.hensYellow, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HT.hensWarm)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(HT.hensYellow, lineWidth: 2)
        )
        .cornerRadius(14)
    }
}

// MARK: - Description Card

private struct HomeDescriptionCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "map.fill")
                .foregroundStyle(HT.hensRed)
                .font(.system(size: 18))
                .padding(.top, 2)

            Text("Join the AR scavenger hunt across UMD. Tap the Map icon to find events and AR characters. Collect creatures, earn points, and climb the leaderboard!")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(HT.hensDimText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(HT.hensWarm)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HT.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - Stats Row

private struct HomeStatsRowView: View {
    let modelController: ModelController

    var body: some View {
        // Section label
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(HT.hensRed)
                Text("Your Stats")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(HT.hensRed)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HT.hensYellowSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(HT.hensYellow, lineWidth: 1.5)
            )
            .cornerRadius(10)

            HStack(spacing: 10) {
                HomeStatChip(label: "Events",       value: "90+")
                HomeStatChip(label: "Collectibles", value: "\(modelController.currentUser?.collectedCount ?? 0)")
                HomeStatChip(label: "Days",         value: "7")
            }
        }
    }
}

private struct HomeStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(HT.hensDimText)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(HT.hensRed)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(HT.hensCream)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(HT.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Confetti Footer

private struct HomeConfettiFooterView: View {
    private let dots: [Color] = [
        HT.hensRed, HT.hensYellow, HT.hensRedSoft, HT.hensYellowSoft,
        HT.hensRed, HT.hensYellow, HT.hensRedSoft, HT.hensYellowSoft,
        HT.hensRed, HT.hensYellow, HT.hensRedSoft, HT.hensYellowSoft
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

// MARK: - Preview

#Preview {
    HomeScreen()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
}
