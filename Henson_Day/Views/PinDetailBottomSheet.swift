import SwiftUI

/// Bottom sheet shown when a map pin is tapped. Displays pin info (type, title,
/// time, location, description) and offers contextual actions: navigate in Apple Maps,
/// open AR collectible, view event details, etc. Supports drag-to-dismiss gesture.
struct PinDetailBottomSheet: View {
    let detail: MapPinDetail
    @Binding var isPresented: Bool
    var onNavigate: () -> Void = {}
    var onPrimaryAction: () -> Void = {}
    var onDetails: (() -> Void)? = nil

    @GestureState private var dragOffset: CGFloat = 0

    private var primaryActionTitle: String? {
        switch detail.pinType {
        case .event:
            return detail.hasARCollectible ? "View in AR" : nil
        case .collectible:
            return "View in AR"
        case .battle:
            return "Start Battle"
        case .homebase:
            return "View Perks"
        case .site, .concert:
            return nil
        }
    }

    private var primaryActionFirst: Bool {
        switch detail.pinType {
        case .collectible, .battle, .homebase:
            return true
        case .event, .site, .concert:
            return false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()

                    sheetBody(geometry: geometry)
                        .offset(y: max(dragOffset, 0))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isPresented)
        }
    }

    private func sheetBody(geometry: GeometryProxy) -> some View {
        let maxHeight = max(geometry.size.height * 0.52, 380)

        return VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Rectangle()
                .fill(detail.pinType.headerColor)
                .frame(height: 34)
                .overlay(alignment: .leading) {
                    Text(detail.pinType.displayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                }

            VStack(alignment: .leading, spacing: 14) {
                Text(detail.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                if !detail.metadataLine.isEmpty {
                    Text(detail.metadataLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(detail.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if detail.hasARCollectible {
                    collectibleCard
                }

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    if let primaryActionTitle, primaryActionFirst {
                        actionButton(title: primaryActionTitle, fill: detail.pinType.headerColor, foreground: .white, action: onPrimaryAction)
                        actionButton(title: "Navigate", fill: .gray.opacity(0.2), foreground: .primary, action: onNavigate)
                    } else {
                        actionButton(title: "Navigate", fill: .gray.opacity(0.2), foreground: .primary, action: onNavigate)

                        if let primaryActionTitle {
                            actionButton(title: primaryActionTitle, fill: detail.pinType.headerColor, foreground: .white, action: onPrimaryAction)
                        }
                    }
                }

                if let onDetails {
                    Button("Details") {
                        onDetails()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: -2)
        .padding(.horizontal, 10)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 10))
        .gesture(dismissDragGesture)
    }

    private var collectibleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Collectible")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(detail.collectibleName ?? "Unknown")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let rarity = detail.collectibleRarity, !rarity.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(rarity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 110 || value.predictedEndTranslation.height > 150
                if shouldDismiss {
                    isPresented = false
                }
            }
    }

    private func actionButton(title: String, fill: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(fill)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Stadium Spirit Rally") {
    @Previewable @State var isPresented = true

    ZStack {
        LinearGradient(colors: [.black, .gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        PinDetailBottomSheet(
            detail: MapPinDetail(
                id: "stadium-spirit-rally",
                pinType: .event,
                title: "Stadium Spirit Rally",
                dayLabel: "Day 1",
                timeRange: "5:00 PM – 7:00 PM",
                locationName: "Maryland Stadium",
                description: "Show your Terp pride at the opening rally, featuring music and performances.",
                collectibleName: "Stadium Stomper",
                collectibleRarity: "Rare",
                hasARCollectible: true
            ),
            isPresented: $isPresented
        )
    }
}
