import SwiftUI
import CoreLocation

/// Compact "quest compass" pill shown in MapScreen's top-right when the user has
/// set a destination. Live-updating distance with a celebratory state when within
/// the AR-launch / battle threshold (`AppConstants.AR.collectibleProximityMeters`).
struct DestinationTrackerPill: View {
    let pin: PinEntity
    let distanceMeters: CLLocationDistance?
    let onClear: () -> Void

    @State private var showReadyDot = false

    private var meters: Int {
        Int((distanceMeters ?? 0).rounded())
    }

    private var isBattleReady: Bool {
        guard let d = distanceMeters else { return false }
        return d <= AppConstants.AR.collectibleProximityMeters
    }

    private var truncatedName: String {
        let name = pin.title
        let limit = 14
        if name.count <= limit { return name }
        return String(name.prefix(limit - 1)) + "…"
    }

    private var accent: Color { pin.pinType.headerColor }

    var body: some View {
        HStack(spacing: 8) {
            iconBadge
            Text(truncatedName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(width: 1, height: 14)

            distanceLabel

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(isBattleReady ? accent.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
        .shadow(
            color: isBattleReady ? accent.opacity(0.35) : .black.opacity(0.12),
            radius: isBattleReady ? 8 : 4,
            x: 0,
            y: 2
        )
        .animation(.easeInOut(duration: 0.3), value: isBattleReady)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                showReadyDot = true
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(isBattleReady ? 1.0 : 0.7))
                .frame(width: 22, height: 22)
            Image(systemName: pin.pinType.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var distanceLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(meters)")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(isBattleReady ? accent : .primary)

            if isBattleReady {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .opacity(showReadyDot ? 1.0 : 0.35)
                    .padding(.leading, 3)
                    .padding(.bottom, 2)
            } else {
                Text("m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Out of range") {
    DestinationTrackerPill(
        pin: previewPin(),
        distanceMeters: 247,
        onClear: {}
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Battle-ready") {
    DestinationTrackerPill(
        pin: previewPin(),
        distanceMeters: 47,
        onClear: {}
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}

private func previewPin() -> PinEntity {
    PinEntity(
        pinType: .event,
        title: "Stadium Spirit Rally",
        subtitle: "Day 1 • 5–7 PM • Maryland Stadium",
        latitude: 38.9889,
        longitude: -76.9442,
        pinDescription: "",
        hasARCollectible: true,
        collectibleName: "Stadium Stomper",
        collectibleRarity: "Rare"
    )
}
