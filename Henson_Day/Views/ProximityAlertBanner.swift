import SwiftUI

struct ProximityAlertBanner: View {
    let pin: PinEntity
    let distance: Double
    let collectibleName: String
    let rarity: String
    let onViewAR: () -> Void
    let onDismiss: () -> Void

    @State private var isPulsing = false

    private var pulseDuration: Double {
        max(0.4, distance / 10.0 * 1.2)
    }

    private var distanceLabel: String {
        "\(Int(distance.rounded()))m away"
    }

    private var rarityBorderColor: Color {
        switch rarity {
        case "Legendary": return .yellow
        case "Rare": return .blue
        default: return .clear
        }
    }

    private var hasGlow: Bool {
        rarity == "Rare" || rarity == "Legendary"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(pin.pinType.headerColor.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)

                Circle()
                    .fill(pin.pinType.headerColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: pin.pinType.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(pin.pinType.headerColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(collectibleName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(distanceLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            Button {
                onViewAR()
            } label: {
                Text("View in AR")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(pin.pinType.headerColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    if hasGlow {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(rarityBorderColor.opacity(0.7), lineWidth: 2)
                    }
                }
                .shadow(color: hasGlow ? rarityBorderColor.opacity(0.3) : .black.opacity(0.15), radius: hasGlow ? 10 : 6)
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            startPulsing()
        }
        .onChange(of: distance) { _, _ in
            // Restart pulse with updated speed
            isPulsing = false
            startPulsing()
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

#Preview {
    VStack {
        Spacer()
        ProximityAlertBanner(
            pin: PinEntity(
                pinType: .collectible,
                title: "McKeldin Mall",
                latitude: 38.9860,
                longitude: -76.9440,
                pinDescription: "Central campus mall",
                hasARCollectible: true,
                collectibleName: "Mall Muppet",
                collectibleRarity: "Common"
            ),
            distance: 25,
            collectibleName: "Mall Muppet",
            rarity: "Common",
            onViewAR: {},
            onDismiss: {}
        )

        ProximityAlertBanner(
            pin: PinEntity(
                pinType: .event,
                title: "Maryland Stadium",
                latitude: 38.9910,
                longitude: -76.9488,
                pinDescription: "Stadium spirit rally",
                hasARCollectible: true,
                collectibleName: "Stadium Stomper",
                collectibleRarity: "Rare"
            ),
            distance: 12,
            collectibleName: "Stadium Stomper",
            rarity: "Rare",
            onViewAR: {},
            onDismiss: {}
        )
    }
    .padding(.bottom, 20)
    .background(Color(.systemGroupedBackground))
}
