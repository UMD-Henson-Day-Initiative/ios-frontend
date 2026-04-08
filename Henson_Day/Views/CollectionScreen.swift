import SwiftUI

struct CollectionScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedTab = 0   // 0 = collected, 1 = catalog
    @State private var selectedCollectible: DatabaseCollectible?
    @Namespace private var segmentNS

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
                DS.Color.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        // Stat strip
                        StatStripView(
                            collected: collectedItems.count,
                            total: modelController.collectibleCatalog.count,
                            points: totalPoints
                        )
                        .padding(.horizontal, DS.Spacing.screenH)

                        // Custom segmented control
                        CollectionSegmentControl(selected: $selectedTab, namespace: segmentNS)
                            .padding(.horizontal, DS.Spacing.screenH)

                        // Content
                        if selectedTab == 0 {
                            collectedList
                        } else {
                            catalogGrid
                        }
                    }
                    .padding(.top, DS.Spacing.card)
                    .padding(.bottom, DS.Spacing.section)
                }
            }
            .navigationTitle("My Collection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileToolbarButton()
                }
            }
            .sheet(item: $selectedCollectible) { collectible in
                CatalogDetailSheet(
                    collectible: collectible,
                    collectedItem: collectedItems.first { $0.collectibleName == collectible.name }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Collected list

    private var collectedList: some View {
        VStack(spacing: DS.Spacing.card) {
            if collectedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.square")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.Color.neutral.opacity(0.4))
                    Text("Nothing captured yet")
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.campusNight)
                    Text("Attend events to find AR collectibles.")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.neutral)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                ForEach(collectedItems, id: \.id) { item in
                    let catalogItem = catalogByName[item.collectibleName]
                    NavigationLink {
                        CollectibleDetailCardScreen(item: item, catalogItem: catalogItem)
                    } label: {
                        CollectedItemRow(item: item, points: catalogItem?.points ?? 0, rarity: catalogItem?.rarity ?? "Common")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.Spacing.screenH)
                }
            }
        }
    }

    // MARK: - Catalog grid (3 columns)

    private var catalogGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.card), count: 3),
            spacing: DS.Spacing.card
        ) {
            ForEach(modelController.collectibleCatalog) { collectible in
                CollectibleGridCell(
                    collectible: collectible,
                    isCollected: collectedNames.contains(collectible.name)
                )
                .onTapGesture {
                    selectedCollectible = collectible
                }
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
    }
}

// MARK: - Stat strip

struct StatStripView: View {
    let collected: Int
    let total: Int
    let points: Int

    var body: some View {
        HStack(spacing: DS.Spacing.card) {
            StatTile(value: "\(collected)/\(total)", label: "Collected", icon: "star.fill")
            StatTile(value: "\(points)", label: "Points",    icon: "bolt.fill")
        }
    }
}

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

// MARK: - Custom segmented control

private struct CollectionSegmentControl: View {
    @Binding var selected: Int
    let namespace: Namespace.ID
    private let tabs = ["Collected", "Catalog"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = index
                    }
                } label: {
                    Text(title)
                        .font(DS.Typography.label)
                        .foregroundStyle(selected == index ? .white : DS.Color.neutral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selected == index {
                                Capsule()
                                    .fill(DS.Color.primary)
                                    .matchedGeometryEffect(id: "segmentBackground", in: namespace)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Collected item row

private struct CollectedItemRow: View {
    let item: CollectedItemEntity
    let points: Int
    let rarity: String

    var body: some View {
        HStack(spacing: 12) {
            // Rarity color dot
            Circle()
                .fill(rarity.rarityColor())
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.collectibleName)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.campusNight)
                Text("\(rarity) · \(item.foundAtTitle)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(points)")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Color.primary)
                Text("pts")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.neutral)
            }
        }
        .padding(DS.Spacing.cardPad)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

// MARK: - Grid cell

private struct CollectibleGridCell: View {
    let collectible: DatabaseCollectible
    let isCollected: Bool

    var body: some View {
        ZStack {
            // Background tinted by rarity
            RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous)
                .fill(collectible.rarity.rarityTint())

            VStack(spacing: 6) {
                // Creature placeholder — SF Symbol as stand-in until custom illustration assets exist
                Image(systemName: isCollected ? "sparkles" : "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isCollected ? collectible.rarity.rarityColor() : DS.Color.neutral.opacity(0.5))
                    .saturation(isCollected ? 1 : 0.3)
                    .blur(radius: isCollected ? 0 : 1)
                    .frame(height: 44)

                Text(collectible.name)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isCollected ? DS.Color.campusNight : DS.Color.neutral)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            .padding(.vertical, 12)

            // Lock overlay for uncollected
            if !isCollected {
                RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous)
                    .fill(Color.black.opacity(0.06))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: DS.Shadow.cardColor, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Catalog detail sheet

private struct CatalogDetailSheet: View {
    let collectible: DatabaseCollectible
    let collectedItem: CollectedItemEntity?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.card) {
                // Header
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(collectible.rarity.rarityTint())
                    Image(systemName: "sparkles")
                        .font(.system(size: 72))
                        .foregroundStyle(collectible.rarity.rarityColor())
                        .padding(.vertical, 32)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .padding(.horizontal, DS.Spacing.screenH)

                VStack(alignment: .leading, spacing: DS.Spacing.card) {
                    HStack {
                        Text(collectible.name)
                            .font(DS.Typography.display)
                            .foregroundStyle(DS.Color.campusNight)
                        Spacer()
                        RarityBadge(rarity: collectible.rarity)
                    }

                    Label(collectible.location, systemImage: "mappin")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.neutral)

                    Text("+\(collectible.points) points")
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.primary)

                    if let item = collectedItem {
                        Divider()
                        Label("Collected \(Self.dateFormatter.string(from: item.foundAtDate))", systemImage: "checkmark.circle.fill")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Color.statusCompleted)
                    } else {
                        Divider()
                        Label("Not yet collected", systemImage: "lock.fill")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Color.neutral)
                    }
                }
                .padding(.horizontal, DS.Spacing.screenH)
                .padding(.bottom, DS.Spacing.section)
            }
            .padding(.top, DS.Spacing.card)
        }
    }
}

// MARK: - Full detail screen (NavigationLink target)

private struct CollectibleDetailCardScreen: View {
    let item: CollectedItemEntity
    let catalogItem: DatabaseCollectible?

    private static let foundDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.card) {
                Text(item.collectibleName)
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Color.campusNight)

                detailRow(title: "Points",     value: "+\(catalogItem?.points ?? 0)")
                detailRow(title: "Rarity",     value: item.rarity)
                detailRow(title: "Found at",   value: item.foundAtTitle)
                detailRow(title: "Found on",   value: Self.foundDateFormatter.string(from: item.foundAtDate))

                if let c = catalogItem {
                    detailRow(title: "Catalog location", value: c.location)
                }
            }
            .padding(DS.Spacing.screenH)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Color.surface.ignoresSafeArea())
        .navigationTitle("Collectible Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.neutral)
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.campusNight)
        }
        .padding(DS.Spacing.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous))
    }
}

#Preview {
    CollectionScreen()
        .environmentObject(ModelController())
}
