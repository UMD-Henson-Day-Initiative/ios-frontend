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
    static let hensCream       = Color(red: 1.00, green: 1.00, blue: 1.00)   // warm off-white
    static let hensWarm        = Color(red: 0.99, green: 0.94, blue: 0.82)   // warm card background
    static let hensMid         = Color(red: 0.97, green: 0.88, blue: 0.72)   // slightly deeper warm
    static let hensDimText     = Color(red: 0.65, green: 0.30, blue: 0.25)   // muted red-brown text
    static let hensFadedText   = Color(red: 0.75, green: 0.45, blue: 0.35)   // softer label text
    static let hensBackground  = Color(red: 1.00, green: 1.00, blue: 1.00)   // full screen bg
}

// MARK: - Main Screen

struct CollectiblesScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedRarity: String? = nil
    @State private var selectedCollectible: DatabaseCollectible?
    @State private var revealCollectible: DatabaseCollectible?

    private var collectedItems: [CollectedItemEntity] {
        UserDatabase.collectedItems(from: modelController)
    }

    private var collectedNames: Set<String> {
        modelController.unlockedCollectibleNames
    }

    private var collectedIDs: Set<String> {
        modelController.unlockedCollectibleIDs
    }

    private var totalPoints: Int {
        modelController.currentUser?.totalPoints ?? 0
    }

    private var totalCP: Int {
        collectedItems.compactMap { item in
            if let collectibleID = item.collectibleID,
               let collectible = modelController.collectibleCatalog.first(where: { $0.id == collectibleID }) {
                return collectible.cp
            }

            return modelController.collectibleCatalog.first { $0.name == item.collectibleName }?.cp
        }.reduce(0, +)
    }

    private var userRank: Int {
        (modelController.leaderboardUsers.firstIndex(where: { $0.id == modelController.currentUser?.id }) ?? 0) + 1
    }

    private var filteredCatalog: [DatabaseCollectible] {
        guard let rarity = selectedRarity else { return modelController.collectibleCatalog }
        return modelController.collectibleCatalog.filter { $0.rarity == rarity }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Festive banner header
                        FestiveBannerHeaderView(
                            collectedCount: collectedItems.count,
                            catalogCount: modelController.collectibleCatalog.count,
                            totalPoints: totalPoints
                        )
                        .ignoresSafeArea(edges: .top)

                    DexStatStrip(
                        caught: collectedItems.count,
                        points: totalPoints,
                        totalCP: totalCP,
                        rank: userRank
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    RarityFilterTabs(selected: $selectedRarity)
                        .padding(.top, 14)

                    ScrollView {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(filteredCatalog.enumerated()), id: \.element.id) { index, item in
                                let dexIdx = (modelController.collectibleCatalog.firstIndex(where: { $0.id == item.id }) ?? index) + 1
                                PokeCell(
                                    collectible: item,
                                    index: index,
                                    dexNumber: dexIdx,
                                    isCollected: collectedIDs.contains(item.id) || collectedNames.contains(item.name)
                                )
                                .onTapGesture { selectedCollectible = item }
                            }
                        }
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

                if let revealCollectible {
                    CodexUnlockRevealOverlay(collectible: revealCollectible) {
                        self.revealCollectible = nil
                        selectedCollectible = revealCollectible
                        modelController.consumePendingCodexReveal(collectibleID: revealCollectible.id)
                    }
                    .zIndex(2)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedCollectible) { collectible in
                DexDetailSheet(
                    collectible: collectible,
                    collectedItem: collectedItems.first {
                        $0.collectibleID == collectible.id || $0.collectibleName == collectible.name
                    },
                    dexNumber: (modelController.collectibleCatalog.firstIndex(where: { $0.id == collectible.id }) ?? 0) + 1
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .onAppear {
                presentPendingCodexRevealIfNeeded()
            }
            .onChange(of: modelController.pendingCodexRevealCollectibleID) { _, _ in
                presentPendingCodexRevealIfNeeded()
            }
            .onChange(of: selectedCollectible?.id) { _, selectedCollectibleID in
                if selectedCollectibleID == nil {
                    presentPendingCodexRevealIfNeeded()
                }
            }
        }
    }

    private func presentPendingCodexRevealIfNeeded() {
        guard revealCollectible == nil else { return }
        guard selectedCollectible == nil else { return }
        guard let collectibleID = modelController.pendingCodexRevealCollectibleID else { return }

        guard let collectible = modelController.collectibleCatalog.first(where: { $0.id == collectibleID }) else {
            modelController.consumePendingCodexReveal(collectibleID: collectibleID)
            return
        }

        selectedRarity = nil
        revealCollectible = collectible
        modelController.consumeLastCapturedCollectibleID()
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

private struct CodexUnlockRevealOverlay: View {
    let collectible: DatabaseCollectible
    let onComplete: () -> Void

    @State private var glowScale: CGFloat = 0.72
    @State private var glowOpacity = 0.2
    @State private var lockOffsetY: CGFloat = -120
    @State private var lockRotation: Double = -10
    @State private var lockOpacity = 1.0
    @State private var swirlRotation = 0.0

    private var swirlColors: [Color] {
        let mapped = collectible.types.map(typeAccentColor(for:))
        return mapped.isEmpty ? [rarityColor(for: collectible.rarity), rarityColor(for: collectible.rarity).opacity(0.35)] : mapped
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("New Codex Entry")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.8)

                ZStack {
                    Circle()
                        .fill(rarityColor(for: collectible.rarity).opacity(0.18))
                        .frame(width: 180, height: 180)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)

                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .trim(from: 0.08, to: 0.62)
                            .stroke(
                                AngularGradient(colors: swirlColors, center: .center),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 156 - CGFloat(index * 18), height: 156 - CGFloat(index * 18))
                            .rotationEffect(.degrees(swirlRotation * (index == 0 ? 1 : -1)))
                            .opacity(0.9 - Double(index) * 0.2)
                    }

                    Text(collectible.emoji)
                        .font(.system(size: 66))

                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: Circle())
                        .offset(y: lockOffsetY)
                        .rotationEffect(.degrees(lockRotation))
                        .opacity(lockOpacity)
                        .shadow(radius: 10, y: 5)
                }
                .frame(width: 200, height: 200)

                VStack(spacing: 6) {
                    Text(collectible.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Text(collectible.rarity.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(rarityColor(for: collectible.rarity))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 28)
        }
        .task {
            withAnimation(.easeOut(duration: 0.45)) {
                glowScale = 1.0
                glowOpacity = 1.0
            }

            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                swirlRotation = 360
            }

            try? await Task.sleep(nanoseconds: 500_000_000)

            withAnimation(.interpolatingSpring(stiffness: 180, damping: 13)) {
                lockOffsetY = 124
                lockRotation = 22
                lockOpacity = 0
            }

            try? await Task.sleep(nanoseconds: 850_000_000)
            onComplete()
        }
    }
}

// MARK: - Dex detail sheet

private struct CollectedListSectionView: View {
    let collectedItems: [CollectedItemEntity]
    let catalogByName: [String: DatabaseCollectible]

    var body: some View {
        ZStack(alignment: .top) {
            DS.Color.surface.ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(UIColor.tertiaryLabel))
                    .frame(width: 36, height: 3)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Stage
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [rarityColor.opacity(0.25), bgCard]),
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 120
                                    )
                                )
                            VStack(spacing: 12) {
                                ZStack {
                                    if let imageName = collectible.imageName {
                                        AvifImage(named: imageName)
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .offset(y: floatOffset)
                                    } else {
                                        Text(collectible.emoji)
                                            .font(.system(size: 64))
                                            .offset(y: floatOffset)
                                    }
                                }
                                .frame(height: 100)

                                Text(collectible.rarity.uppercased())
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(rarityColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(rarityColor.opacity(0.15))
                                    .clipShape(Capsule())

                                Text(collectible.name)
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundStyle(textHi)

                                HStack(spacing: 6) {
                                    Text(String(format: "#%03d", dexNumber))
                                        .font(.system(size: 12, weight: .medium).monospaced())
                                        .foregroundStyle(textMid)
                                    if collectedItem != nil {
                                        Text("·").foregroundStyle(textLo)
                                        Text("Collected Day \(dayNumber)")
                                            .font(.system(size: 12, weight: .medium).monospaced())
                                            .foregroundStyle(textMid)
                                    }
                                }

                                HStack(spacing: 6) {
                                    ForEach(collectible.types, id: \.self) { t in
                                        Text(t.uppercased())
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(rarityColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(rarityColor.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 24)
                        }
                        .padding(.horizontal, 20)

                        // Stats row
                        HStack(spacing: 0) {
                            DexDetailStat(value: "\(collectible.cp)", label: "CP", color: dkLeg)
                            Rectangle().fill(Color(UIColor.separator).opacity(0.3)).frame(width: 1, height: 44)
                            DexDetailStat(value: "+\(collectible.points)", label: "POINTS", color: textHi)
                            Rectangle().fill(Color(UIColor.separator).opacity(0.3)).frame(width: 1, height: 44)
                            DexDetailStat(
                                value: collectedItem != nil ? "✓" : "–",
                                label: "IN DEX",
                                color: collectedItem != nil ? dkCommon : textLo
                            )
                            Rectangle().fill(Color(UIColor.separator).opacity(0.3)).frame(width: 1, height: 44)
                            DexDetailStat(value: "🏅", label: "BADGE", color: textHi)
                        }
                        .frame(maxWidth: .infinity)
                        .background(bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(UIColor.separator).opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)

                        // CP bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("POWER LEVEL")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(textMid)
                                    .tracking(0.5)
                                Spacer()
                                Text("\(collectible.cp) / 2200 CP")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(textMid)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(bgCard).frame(height: 6)
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [dkRare, dkLeg],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * CGFloat(collectible.cp) / 2200.0, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(16)
                        .background(bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("DESCRIPTION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(textMid)
                                .tracking(0.8)
                            Text(collectible.flavorText)
                                .font(.system(size: 14))
                                .foregroundStyle(textHi)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)

                        if let item = collectedItem {
                            HStack(spacing: 8) {
                                Circle().fill(dkCommon).frame(width: 8, height: 8)
                                Text("Caught at \(item.foundAtTitle) · Day \(dayNumber)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(textMid)
                            }
                        }

                        Button { dismiss() } label: {
                            Text("Done")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DS.Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
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

private func rarityColor(for rarity: String) -> Color {
    switch rarity {
    case "Common":    return dkCommon
    case "Rare":      return dkRare
    case "Epic":      return dkEpic
    case "Legendary": return dkLeg
    default:          return dkCommon
    }
}

private func typeAccentColor(for type: String) -> Color {
    switch type.lowercased() {
    case "fire", "sound", "mystic":
        return Color(hex: "#FF7A45")
    case "water", "shadow":
        return Color(hex: "#3F8CFF")
    case "electric", "tech", "smart":
        return Color(hex: "#F5C542")
    case "nature", "normal":
        return Color(hex: "#57B65F")
    case "psychic":
        return Color(hex: "#B06CFF")
    case "ground", "steel":
        return Color(hex: "#8C6B52")
    case "speed", "fighting":
        return Color(hex: "#E44D5E")
    default:
        return dkRare
    }
}

private struct DexDetailStat: View {
    let value: String
    let label: String
    let color: Color

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
