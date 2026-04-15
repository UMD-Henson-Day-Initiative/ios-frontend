//  CollectibleScreen.swift
//  Henson_Day
//
//  File Description: This file defines the CollectiblesScreen, which displays the user's collected
//  collectibles and the full collectible catalog. It includes a stat summary header, a unified
//  badge gallery showing all catalog badges (collected and uncollected), a scrollable list of
//  collected items with navigation to detail cards. It also defines CollectedItemCardView for
//  list rows and CollectibleDetailCardScreen for the full detail view of a collected item.
//

import SwiftUI

// MARK: - Theme Colors

private enum CT {
    static let hensRed         = Color(red: 0.85, green: 0.15, blue: 0.15)   // lighter terp red
    static let hensRedSoft     = Color(red: 0.95, green: 0.35, blue: 0.35)   // pinkish-red accent
    static let hensRedPale     = Color(red: 1.00, green: 0.88, blue: 0.88)   // blush background tint
    static let hensYellow      = Color(red: 1.00, green: 0.85, blue: 0.20)   // warm gold-yellow
    static let hensYellowSoft  = Color(red: 1.00, green: 0.93, blue: 0.55)   // soft butter yellow
    static let hensCream       = Color(red: 1.00, green: 0.97, blue: 0.90)   // warm off-white
    static let hensWarm        = Color(red: 0.99, green: 0.94, blue: 0.82)   // warm card background
    static let hensMid         = Color(red: 0.97, green: 0.88, blue: 0.72)   // slightly deeper warm
    static let hensDimText     = Color(red: 0.65, green: 0.30, blue: 0.25)   // muted red-brown text
    static let hensFadedText   = Color(red: 0.75, green: 0.45, blue: 0.35)   // softer label text
    static let hensBackground  = Color(red: 1.00, green: 0.96, blue: 0.90)   // full screen bg
}

// MARK: - Main Screen

struct CollectiblesScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedTab = 0

    private var collectedItems: [CollectedItemEntity] {
        UserDatabase.collectedItems(from: modelController)
    }

    private var collectedNames: Set<String> {
        Set(collectedItems.map(\.collectibleName))
    }

    private var totalPoints: Int {
        modelController.currentUser?.totalPoints ?? 0
    }

    private var catalogByName: [String: DatabaseCollectible] {
        Dictionary(uniqueKeysWithValues: modelController.collectibleCatalog.map { ($0.name, $0) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CT.hensBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Festive banner header
                        FestiveBannerHeaderView(
                            collectedCount: collectedItems.count,
                            catalogCount: modelController.collectibleCatalog.count,
                            totalPoints: totalPoints
                        )
                        .ignoresSafeArea(edges: .top)

                        // Unified Badges section
                        BadgesSectionView(
                            catalog: modelController.collectibleCatalog,
                            collectedNames: collectedNames
                        )
                        .padding(.top, 16)
                        .padding(.horizontal, 16)

                        // Collected list
                        CollectedListSectionView(
                            collectedItems: collectedItems,
                            catalogByName: catalogByName
                        )
                        .padding(.top, 20)
                        .padding(.horizontal, 16)

                        ConfettiFooterView()
                            .padding(.top, 24)
                            .padding(.bottom, 12)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Festive Banner Header

private struct FestiveBannerHeaderView: View {
    let collectedCount: Int
    let catalogCount: Int
    let totalPoints: Int

    var body: some View {
        ZStack(alignment: .top) {
            CT.hensRed

            VStack(spacing: 0) {
                // Bunting / flag garland
                BuntingView()

                // Title pennant
                PennantTitleView(title: "My Collection")
                    .padding(.top, 8)

                // Stat chips
                HStack(spacing: 10) {
                    FestiveStatChip(label: "Collected", value: "\(collectedCount)/\(catalogCount)")
                    FestiveStatChip(label: "Points",    value: "\(totalPoints)")
                    FestiveStatChip(label: "Badges",    value: "3/3")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
        }
    }
}

// MARK: - Bunting

private struct BuntingView: View {
    private let flagCount = 8
    private let flagColors: [Color] = [
        CT.hensRed, CT.hensYellow, CT.hensRedSoft, CT.hensYellowSoft,
        CT.hensRed, CT.hensYellow, CT.hensRedSoft, CT.hensYellowSoft
    ]

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(flagCount)
            let ropeY: CGFloat = 18

            // Rope line
            var rope = Path()
            rope.move(to: CGPoint(x: 0, y: ropeY))
            rope.addLine(to: CGPoint(x: size.width, y: ropeY))
            context.stroke(rope, with: .color(CT.hensYellow.opacity(0.9)), lineWidth: 1.5)

            // Triangle flags
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
                context.stroke(flag, with: .color(CT.hensYellow.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Pennant Title

private struct PennantTitleView: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(CT.hensYellow)

            // Small dot row beneath title
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { _ in
                    Circle()
                        .fill(CT.hensYellowSoft.opacity(0.80))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 32)
        .background(CT.hensRed.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(CT.hensYellow, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

// MARK: - Festive Stat Chip

private struct FestiveStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(CT.hensDimText)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(CT.hensRed)
        }
        .frame(maxWidth: 100)
        .padding(.vertical, 8)
        .background(CT.hensCream)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(CT.hensYellow, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
}

// MARK: - Badges Section (unified collected + catalog)

private struct BadgesSectionView: View {
    let catalog: [DatabaseCollectible]
    let collectedNames: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section banner
            HStack {
                Image(systemName: "rosette")
                    .foregroundStyle(CT.hensRed)
                Text("Badges")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(CT.hensRed)
                Spacer()
                Text("\(collectedNames.count)/\(catalog.count) collected")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CT.hensDimText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(CT.hensYellowSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(CT.hensYellow, lineWidth: 1.5)
            )
            .cornerRadius(10)

            // Badge grid
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(catalog) { collectible in
                    WhimsicalBadgeCardView(
                        collectible: collectible,
                        isUnlocked: collectedNames.contains(collectible.name)
                    )
                }
            }
        }
    }
}

// MARK: - Whimsical Badge Card

private struct WhimsicalBadgeCardView: View {
    let collectible: DatabaseCollectible
    let isUnlocked: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                // Badge icon circle
                ZStack {
                    Circle()
                        .fill(isUnlocked ? CT.hensYellowSoft : CT.hensMid.opacity(0.5))
                        .frame(width: 48, height: 48)
                    Circle()
                        .strokeBorder(
                            isUnlocked ? CT.hensYellow : CT.hensFadedText.opacity(0.4),
                            lineWidth: 2
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: isUnlocked ? "star.fill" : "star")
                        .foregroundStyle(isUnlocked ? CT.hensRed : CT.hensFadedText.opacity(0.5))
                        .font(.system(size: 20))
                }

                Text(collectible.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isUnlocked ? CT.hensRed : CT.hensFadedText.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("+\(collectible.points) pts")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isUnlocked ? CT.hensDimText : CT.hensFadedText.opacity(0.4))
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(isUnlocked ? CT.hensWarm : CT.hensMid.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isUnlocked ? CT.hensRed : CT.hensDimText.opacity(0.5),
                        lineWidth: isUnlocked ? 2.5 : 1.5
                    )
            )
            .cornerRadius(12)

            // Lock overlay for uncollected
            if !isUnlocked {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.38))
                Image(systemName: "lock.fill")
                    .foregroundStyle(CT.hensFadedText.opacity(0.7))
                    .font(.system(size: 16))
            }
        }
    }
}

// MARK: - Collected List Section

private struct CollectedListSectionView: View {
    let collectedItems: [CollectedItemEntity]
    let catalogByName: [String: DatabaseCollectible]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section label
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(CT.hensRed)
                Text("Collected Items")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(CT.hensRed)
            }
            .padding(.bottom, 2)

            if collectedItems.isEmpty {
                Text("Nothing collected yet — go explore Henson Day! 🎉")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(CT.hensDimText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CT.hensWarm)
                    .cornerRadius(10)
            } else {
                ForEach(collectedItems, id: \.id) { item in
                    let catalogItem = catalogByName[item.collectibleName]
                    NavigationLink {
                        CollectibleDetailCardScreen(item: item, catalogItem: catalogItem)
                    } label: {
                        WhimsicalItemRowView(item: item, points: catalogItem?.points ?? 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Whimsical Item Row

private struct WhimsicalItemRowView: View {
    let item: CollectedItemEntity
    let points: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left accent dot
            Circle()
                .fill(CT.hensRedSoft)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.collectibleName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(CT.hensRed)

                Text("\(item.rarity) · Found at \(item.foundAtTitle)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CT.hensDimText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("+\(points)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(CT.hensRed)
                Text("pts")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(CT.hensDimText)
            }
        }
        .padding(12)
        .background(CT.hensWarm)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(CT.hensYellow, lineWidth: 1.2)
        )
        .cornerRadius(12)
    }
}

// MARK: - Confetti Footer

private struct ConfettiFooterView: View {
    private let dots: [Color] = [
        CT.hensRed, CT.hensYellow, CT.hensRedSoft, CT.hensYellowSoft,
        CT.hensRed, CT.hensYellow, CT.hensRedSoft, CT.hensYellowSoft,
        CT.hensRed, CT.hensYellow, CT.hensRedSoft, CT.hensYellowSoft
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

// MARK: - Detail Screen

private struct CollectibleDetailCardScreen: View {
    let item: CollectedItemEntity
    let catalogItem: DatabaseCollectible?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            CT.hensBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.collectibleName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CT.hensRed)
                        .padding(.bottom, 4)

                    detailRow(title: "Points",   value: "+\(catalogItem?.points ?? 0)")
                    detailRow(title: "Rarity",   value: item.rarity)
                    detailRow(title: "Found at", value: item.foundAtTitle)
                    detailRow(title: "Found on", value: Self.dateFormatter.string(from: item.foundAtDate))

                    if let catalogItem {
                        detailRow(title: "Catalog location", value: catalogItem.location)
                        detailRow(title: "Model asset",      value: catalogItem.modelFileName)
                        detailRow(title: "Collectible ID",   value: catalogItem.id)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CT.hensRed, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(CT.hensDimText)
            Text(value)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(CT.hensRed)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CT.hensWarm)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(CT.hensYellow, lineWidth: 1.2)
        )
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    CollectiblesScreen()
        .environmentObject(ModelController())
}
