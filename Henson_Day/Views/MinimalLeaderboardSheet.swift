import SwiftUI

struct MinimalLeaderboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let players: [PlayerEntity]
    let localUserID: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        Circle()
                            .fill(Color(hex: player.avatarColorHex))
                            .frame(width: 24, height: 24)
                            .overlay {
                                Image(systemName: player.avatarType.symbolName)
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }

                        Text(player.displayName)
                            .font(.body.weight(player.id == localUserID ? .semibold : .regular))

                        Spacer()

                        Text("\(player.totalPoints)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(player.id == localUserID ? Color.primary.opacity(0.06) : Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
