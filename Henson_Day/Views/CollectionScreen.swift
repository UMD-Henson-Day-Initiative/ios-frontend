import SwiftUI

/// Displays the user's collected items and the full collectible catalog.
/// Tabs switch between "Collected" (items the user has found) and "Catalog"
/// (all available collectibles with collected/uncollected status).
struct CollectionScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedTab = 0  // 0 = collected, 1 = catalog

    private var collectedItems: [CollectedItemEntity] {
        UserDatabase.collectedItems(from: modelController)
    }

    private var collectedNames: Set<String> {
        Set(collectedItems.map(\.collectibleName))
    }

    private var totalPointsFromCollection: Int {
        modelController.currentUser?.totalPoints ?? 0
    }

    private var catalogByName: [String: DatabaseCollectible] {
        Dictionary(uniqueKeysWithValues: modelController.collectibleCatalog.map { ($0.name, $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatChip(
                            title: "Collected",
                            value: "\(collectedItems.count)/\(modelController.collectibleCatalog.count)",
                            color: Color("UMDRed")
                        )
                        StatChip(
                            title: "Points",
                            value: "\(totalPointsFromCollection)",
                            color: Color("UMDGold")
                        )
                        StatChip(
                            title: "Badges",
                            value: "3/3",
                            color: .orange
                        )
                    }

                    Picker("", selection: $selectedTab) {
                        Text("Collected").tag(0)
                        Text("Catalog").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == 0 {
                        collectedList
                    } else {
                        catalogGrid
                    }
                }
                .padding()
            }
            .navigationTitle("My Collection")
        }
    }

    private var collectedList: some View {
        VStack(spacing: 10) {
            if collectedItems.isEmpty {
                Text("No collectibles captured yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(collectedItems, id: \.id) { item in
                    let catalogItem = catalogByName[item.collectibleName]

                    NavigationLink {
                        CollectibleDetailCardScreen(item: item, catalogItem: catalogItem)
                    } label: {
                        CollectedItemCardView(item: item, points: catalogItem?.points ?? 0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var catalogGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(modelController.collectibleCatalog) { collectible in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(collectible.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(collectible.rarity)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(collectible.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("+\(collectible.points) pts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("UMDRed"))
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.2))
                )
                .overlay {
                    if !collectedNames.contains(collectible.name) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.18))
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.white)
                            )
                    }
                }
            }
        }
    }
}

private struct CollectedItemCardView: View {
    let item: CollectedItemEntity
    let points: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.collectibleName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(item.rarity) • Found at \(item.foundAtTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(points)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color("UMDRed"))
                Text("pts")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CollectibleDetailCardScreen: View {
    let item: CollectedItemEntity
    let catalogItem: DatabaseCollectible?

    private static let foundDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.collectibleName)
                    .font(.title3.weight(.bold))

                detailRow(title: "Points", value: "+\(catalogItem?.points ?? 0)")
                detailRow(title: "Rarity", value: item.rarity)
                detailRow(title: "Found at", value: item.foundAtTitle)
                detailRow(title: "Found on", value: Self.foundDateFormatter.string(from: item.foundAtDate))

                if let catalogItem {
                    detailRow(title: "Catalog location", value: catalogItem.location)
                    detailRow(title: "Model asset", value: catalogItem.modelFileName)
                    detailRow(title: "Collectible ID", value: catalogItem.id)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Collectible Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    CollectionScreen()
        .environmentObject(ModelController())
}
