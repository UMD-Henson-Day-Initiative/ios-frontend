import SwiftUI

struct CollectionScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0  // 0 = collectibles, 1 = badges

    var obtainedCount: Int {
        appState.collectibles.filter { $0.obtained }.count
    }

    var totalPoints: Int {
        appState.collectibles.filter { $0.obtained }.map(\.points).reduce(0, +)
    }

    var unlockedBadges: Int {
        appState.badges.filter { $0.unlocked }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header stats
                    HStack(spacing: 12) {
                        StatChip(
                            title: "Collected",
                            value: "\(obtainedCount)/\(appState.collectibles.count)",
                            color: Color("UMDRed")
                        )
                        StatChip(
                            title: "Points",
                            value: "\(totalPoints)",
                            color: Color("UMDGold")
                        )
                        StatChip(
                            title: "Badges",
                            value: "\(unlockedBadges)/\(appState.badges.count)",
                            color: .orange
                        )
                    }

                    // Segmented control
                    Picker("", selection: $selectedTab) {
                        Text("Collectibles").tag(0)
                        Text("Badges").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == 0 {
                        collectiblesGrid
                    } else {
                        badgesList
                    }
                }
                .padding()
            }
            .navigationTitle("My Collection")
        }
    }

    // MARK: - Subviews

    private var collectiblesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(appState.collectibles) { c in
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 100)

                        // Use your emoji; if Collectible.emoji is non-optional, remove ??
                        Text(c.emoji)
                            .font(.system(size: 40))
                    }

                    HStack {
                        Text(c.name)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(c.points)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.gray.opacity(0.2))
                )
                .overlay(
                    Group {
                        if !c.obtained {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.black.opacity(0.25))
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                )
            }
        }
    }

    // Simple badges list
    private var badgesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(appState.badges) { badge in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(badge.unlocked ? Color.green.opacity(0.2)
                                                 : Color.gray.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: badge.unlocked ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(badge.unlocked ? .green : .gray)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.name)            // <- use .name, not .title
                            .font(.headline)
                        Text(badge.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if badge.unlocked {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }
}

#Preview {
    CollectionScreen()
}
