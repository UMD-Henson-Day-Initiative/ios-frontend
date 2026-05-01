import SwiftUI

struct CollectionScreen: View {
    @EnvironmentObject private var modelController: ModelController
    @State private var selectedRarity: String? = nil
    @State private var selectedCollectible: DatabaseCollectible?

    private var collectedItems: [CollectedItemEntity] {
        UserDatabase.collectedItems(from: modelController)
    }

    private var collectedIDs: Set<String> {
        modelController.unlockedCollectibleIDs
    }

    private var collectedNames: Set<String> {
        modelController.unlockedCollectibleNames
    }

    private var rarityOptions: [String] {
        let all = modelController.collectibleCatalog.map(\.rarity)
        return Array(Set(all)).sorted()
    }

    private var filteredCatalog: [DatabaseCollectible] {
        guard let selectedRarity else { return modelController.collectibleCatalog }
        return modelController.collectibleCatalog.filter { $0.rarity == selectedRarity }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                headerStats
                rarityFilter

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredCatalog, id: \.id) { collectible in
                            collectibleCard(collectible)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Collection")
            .sheet(item: $selectedCollectible) { collectible in
                CollectibleDetailSheet(
                    collectible: collectible,
                    collectedItem: collectedItems.first {
                        $0.collectibleID == collectible.id || $0.collectibleName == collectible.name
                    }
                )
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 12) {
            statPill(title: "Collected", value: "\(collectedItems.count)")
            statPill(title: "Catalog", value: "\(modelController.collectibleCatalog.count)")
            statPill(title: "Points", value: "\(modelController.currentUser?.totalPoints ?? 0)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var rarityFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                rarityChip(title: "All", isSelected: selectedRarity == nil) {
                    selectedRarity = nil
                }

                ForEach(rarityOptions, id: \.self) { rarity in
                    rarityChip(title: rarity, isSelected: selectedRarity == rarity) {
                        selectedRarity = rarity
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func collectibleCard(_ collectible: DatabaseCollectible) -> some View {
        let isCollected = collectedIDs.contains(collectible.id) || collectedNames.contains(collectible.name)

        return Button {
            selectedCollectible = collectible
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(collectible.rarity)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(rarityColor(collectible.rarity).opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: isCollected ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundStyle(isCollected ? .green : .secondary)
                }

                Text(collectible.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("+\(collectible.points) pts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("CP \(collectible.cp)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rarityChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.red : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity.lowercased() {
        case "legendary":
            return .yellow
        case "epic":
            return .purple
        case "rare":
            return .blue
        default:
            return .green
        }
    }
}

private struct CollectibleDetailSheet: View {
    let collectible: DatabaseCollectible
    let collectedItem: CollectedItemEntity?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    detailRow("Name", collectible.name)
                    detailRow("Rarity", collectible.rarity)
                    detailRow("Points", "+\(collectible.points)")
                    detailRow("CP", "\(collectible.cp)")
                    detailRow("Location", collectible.location)
                }

                if let collectedItem {
                    Section("Collected") {
                        detailRow("Found at", collectedItem.foundAtTitle)
                        detailRow("Found on", Self.dateFormatter.string(from: collectedItem.foundAtDate))
                    }
                }
            }
            .navigationTitle("Collectible")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

typealias CollectiblesScreen = CollectionScreen

#Preview {
    CollectionScreen()
        .environmentObject(ModelController())
}
