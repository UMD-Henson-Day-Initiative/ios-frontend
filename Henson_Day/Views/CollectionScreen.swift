import SwiftUI

// MARK: - Light-mode palette (Collection / UMD Index)
private let bgDeep    = DS.Color.surface
private let bgMid     = DS.Color.surface
private let bgCard    = DS.Color.surfaceElevated
private let bgCardHi  = Color(UIColor.secondarySystemBackground)
private let bgSurface = Color(UIColor.tertiarySystemBackground)
private let textHi    = DS.Color.campusNight
private let textMid   = DS.Color.neutral
private let textLo    = Color(UIColor.tertiaryLabel)
private let dkCommon  = DS.Color.Rarity.common
private let dkRare    = DS.Color.Rarity.rare
private let dkEpic    = DS.Color.Rarity.epic
private let dkLeg     = DS.Color.Rarity.legendary
private let dkCrimson = DS.Color.primary

// MARK: - CollectionScreen
struct CollectionScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedRarity: String? = nil
    @State private var selectedCollectible: DatabaseCollectible?

    private var collectedItems: [CollectedItemEntity] {
        UserDatabase.collectedItems(from: modelController)
    }

    private var collectedNames: Set<String> {
        Set(collectedItems.map(\.collectibleName))
    }

    private var totalPoints: Int {
        modelController.currentUser?.totalPoints ?? 0
    }

    private var totalCP: Int {
        collectedItems.compactMap { item in
            modelController.collectibleCatalog.first { $0.name == item.collectibleName }?.cp
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
                DS.Color.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    DexHeader(
                        caught: collectedItems.count,
                        total: modelController.collectibleCatalog.count
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

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
                                    isCollected: collectedNames.contains(item.name)
                                )
                                .onTapGesture { selectedCollectible = item }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedCollectible) { collectible in
                DexDetailSheet(
                    collectible: collectible,
                    collectedItem: collectedItems.first { $0.collectibleName == collectible.name },
                    dexNumber: (modelController.collectibleCatalog.firstIndex(where: { $0.id == collectible.id }) ?? 0) + 1
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

// MARK: - Dex header

private struct DexHeader: View {
    let caught: Int
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("UMD Index")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(textHi)
            Text(" #")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(dkRare)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(caught)/\(total) caught")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(dkRare)
                Text(String(format: "#%03d–#%03d", 1, total))
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(textMid)
            }
        }
    }
}

// MARK: - Stat strip

private struct DexStatStrip: View {
    let caught: Int
    let points: Int
    let totalCP: Int
    let rank: Int

    var body: some View {
        HStack(spacing: 8) {
            DexChip(value: "\(caught)", label: "CAUGHT", valueColor: dkCommon)
            DexChip(value: "\(points)", label: "POINTS", valueColor: dkLeg)
            DexChip(value: "CP \(totalCP)", label: "TOTAL CP", valueColor: textHi)
            DexChip(value: "#\(rank)", label: "RANK", valueColor: dkRare)
        }
    }
}

private struct DexChip: View {
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(textMid)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.cardColor, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Rarity filter tabs

private struct RarityFilterTabs: View {
    @Binding var selected: String?

    private let rarities: [(label: String, value: String?)] = [
        ("All", nil),
        ("✦ Common", "Common"),
        ("◆ Rare", "Rare"),
        ("◈ Epic", "Epic"),
        ("✦✦ Legendary", "Legendary")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rarities, id: \.label) { rarity in
                    let isActive = selected == rarity.value
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = rarity.value
                        }
                    } label: {
                        Text(rarity.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? .white : textLo)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isActive ? dkRare : Color.clear)
                                    .shadow(color: isActive ? dkRare.opacity(0.4) : .clear, radius: 8, x: 0, y: 0)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isActive ? Color.clear : textLo.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Pokédex cell

private struct PokeCell: View {
    let collectible: DatabaseCollectible
    let index: Int
    let dexNumber: Int
    let isCollected: Bool

    @State private var floatOffset: CGFloat = 0

    private var rarityColor: Color {
        switch collectible.rarity {
        case "Common":    return dkCommon
        case "Rare":      return dkRare
        case "Epic":      return dkEpic
        case "Legendary": return dkLeg
        default:          return dkCommon
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bgCard)
                .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(rarityColor.opacity(isCollected ? 0.25 : 0.08), lineWidth: 1)
                )

            RadialGradient(
                gradient: Gradient(colors: [rarityColor.opacity(0.12), Color.clear]),
                center: .top,
                startRadius: 0,
                endRadius: 80
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 0) {
                HStack {
                    Text(String(format: "#%03d", dexNumber))
                        .font(.system(size: 8, weight: .bold).monospaced())
                        .foregroundStyle(textLo)
                    Spacer()
                    Circle()
                        .fill(rarityColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: rarityColor.opacity(0.8), radius: 3, x: 0, y: 0)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                GeometryReader { geo in
                    ZStack {
                        if isCollected {
                            if let imageName = collectible.imageName {
                                AvifImage(named: imageName)
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                                    .offset(y: floatOffset)
                            } else {
                                Text(collectible.emoji)
                                    .font(.system(size: 38))
                                    .offset(y: floatOffset)
                            }
                        } else {
                            Text(collectible.emoji)
                                .font(.system(size: 38))
                                .opacity(0.12)
                            Text("🔒")
                                .font(.system(size: 18))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: 72)
                .clipped()

                VStack(spacing: 2) {
                    Text(collectible.name)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(textHi)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 3) {
                        ForEach(collectible.types, id: \.self) { t in
                            Text(t.uppercased())
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(rarityColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(rarityColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.92))
            }

            if isCollected {
                Text("CP \(collectible.cp)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Color.campusNight)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 22)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .aspectRatio(0.75, contentMode: .fit)
        .onAppear {
            let delay = Double(index % 6) * 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    floatOffset = -3
                }
            }
        }
    }
}

// MARK: - Dex detail sheet

private struct DexDetailSheet: View {
    let collectible: DatabaseCollectible
    let collectedItem: CollectedItemEntity?
    let dexNumber: Int

    @State private var floatOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    private var rarityColor: Color {
        switch collectible.rarity {
        case "Common":    return dkCommon
        case "Rare":      return dkRare
        case "Epic":      return dkEpic
        case "Legendary": return dkLeg
        default:          return dkCommon
        }
    }

    private var dayNumber: Int {
        let calendar = Calendar.current
        let collected = collectedItem?.foundAtDate ?? Date()
        let diff = calendar.dateComponents([.day], from: AppConstants.Schedule.weekStart, to: collected).day ?? 0
        return max(1, diff + 1)
    }

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

                        Text(collectible.flavorText)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(textMid)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

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
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                floatOffset = -4
            }
        }
    }
}

private struct DexDetailStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(textMid)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - StatTile (shared with HomeScreen)

struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.Color.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

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
    CollectionScreen()
        .environmentObject(ModelController())
}
