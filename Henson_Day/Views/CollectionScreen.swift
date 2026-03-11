import SwiftUI

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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.collectibleName)
                                .font(.headline)
                            Text("\(item.rarity) • Found at \(item.foundAtTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

#Preview {
    CollectionScreen()
        .environmentObject(ModelController())
}
