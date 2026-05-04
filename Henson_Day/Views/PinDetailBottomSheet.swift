//  PinDetailBottomSheet.swift
//  Henson_Day
//
//  File Description: This file defines a SwiftUI bottom sheet view for displaying detailed
//  information about a map pin within the app. The sheet includes the pin's
//  title, description, metadata, and any associated AR collectibles. It
//  supports primary actions (e.g., view in AR, start battle), navigation,
//  and an optional "Details" button. The sheet can be dismissed via a
//  drag gesture or programmatically.
//

import SwiftUI
import CoreLocation
import UIKit

/// Bottom sheet shown when a map pin is tapped. Displays pin info (type, title,
/// time, location, description) and offers contextual actions: navigate in Apple Maps,
/// open AR collectible, view event details, etc. Supports drag-to-dismiss gesture.
struct PinDetailBottomSheet: View {
    let detail: MapPinDetail
    let pinCoordinate: CLLocationCoordinate2D
    var userLocation: CLLocationCoordinate2D? = nil
    @Binding var isPresented: Bool
    var onPrimaryAction: () -> Void = {}
    var onDetails: (() -> Void)? = nil
    var onSetDestination: (() -> Void)? = nil
    var isCurrentDestination: Bool = false

    @State private var dragTranslation: CGFloat = 0
    @State private var currentDetent: SheetDetent = .medium
    @State private var showProximityAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isOverscrollDragging = false

    private enum SheetDetent {
        case medium
        case large

        func height(in geometry: GeometryProxy) -> CGFloat {
            switch self {
            case .medium:
                return max(geometry.size.height * 0.62, 440)
            case .large:
                return geometry.size.height * 0.92
            }
        }
    }

    private var distanceMeters: CLLocationDistance? {
        straightLineDistance(from: userLocation, to: pinCoordinate)
    }

    private var isBattleRelevant: Bool {
        detail.hasARCollectible || detail.pinType == .battle
    }

    private var isBattleReady: Bool {
        guard let d = distanceMeters else { return false }
        return d <= AppConstants.AR.collectibleProximityMeters
    }

    private var metersToBattle: Int {
        guard let d = distanceMeters else { return 0 }
        return max(0, Int((d - AppConstants.AR.collectibleProximityMeters).rounded()))
    }

    private var dismissDragOpacity: Double {
        let progress = min(1.0, max(0, Double(dragTranslation)) / 220.0)
        return 1.0 - progress * 0.85
    }

    private var primaryActionTitle: String? {
        guard detail.availability.isActive else { return nil }

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

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                isPresented = false
                            }
                        }

                    sheetBody(geometry: geometry)
                        .offset(y: max(0, dragTranslation))
                        .opacity(dismissDragOpacity)
                        .animation(nil, value: dragTranslation)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isPresented)
        }
    }

    private func sheetBody(geometry: GeometryProxy) -> some View {
        let baseHeight = currentDetent.height(in: geometry)
        let upwardDelta = max(0, -dragTranslation)
        let liveHeight = min(baseHeight + upwardDelta, geometry.size.height * 0.96)

        return VStack(spacing: 0) {
            grabber
                .gesture(dismissDragGesture)

            scrollableBody

            actionFooter
        }
        .frame(maxWidth: .infinity)
        .frame(height: liveHeight, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: -6)
        .padding(.horizontal, 8)
        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 10))
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    private var heroHeader: some View {
        let tint = detail.pinType.headerColor

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.22))
                    .frame(width: 56, height: 56)
                Image(systemName: detail.pinType.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.pinType.displayLabel.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.85))

                Text(detail.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.metadataLine.isEmpty {
                    Text(detail.metadataLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .contentShape(Rectangle())
    }

    private var scrollableBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader

                VStack(alignment: .leading, spacing: 14) {
                    if distanceMeters != nil {
                        distanceRow
                    }

                    availabilityChip

                    Text(detail.description)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let availabilityMessage = detail.availability.message {
                        availabilityCard(message: availabilityMessage)
                    }

                    if detail.hasARCollectible {
                        collectibleCard
                    }

                    Color.clear.frame(height: 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: proxy.frame(in: .named("sheetScroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "sheetScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { newOffset in
            scrollOffset = newOffset
        }
        .scrollDisabled(isOverscrollDragging)
        .simultaneousGesture(overscrollDismissGesture)
    }

    private var overscrollDismissGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                // Switch into overscroll-drag mode the first time we detect
                // "at top + dragging down" — this locks the ScrollView so its
                // bounce stops fighting the sheet movement.
                if !isOverscrollDragging
                    && scrollOffset >= 0
                    && value.translation.height > 0 {
                    isOverscrollDragging = true
                }

                guard isOverscrollDragging else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragTranslation = max(0, value.translation.height)
                }
            }
            .onEnded { value in
                guard isOverscrollDragging else { return }
                isOverscrollDragging = false
                handleDragEnd(value)
            }
    }

    private var actionFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if let primaryActionTitle {
                        actionButton(
                            title: primaryActionTitle,
                            fill: detail.pinType.headerColor,
                            foreground: .white
                        ) {
                            if primaryActionTitle == "View in AR" {
                                checkProximityAndLaunchAR()
                            } else {
                                onPrimaryAction()
                            }
                        }
                    }

                    actionButton(title: "Navigate", fill: Color(.systemGray6), foreground: .primary) {
                        openInMaps()
                    }

                    if let onDetails {
                        actionButton(title: "Details", fill: Color(.systemGray6), foreground: .primary) {
                            onDetails()
                        }
                    }
                }
                .alert("Not Close Enough", isPresented: $showProximityAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please navigate to the location to collect the muppet.")
                }

                if onSetDestination != nil {
                    destinationToggleButton
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(Color(.systemBackground))
    }

    private var collectibleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.availability.isActive ? "Available Collectible" : "Collectible Status")
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

    private var availabilityChip: some View {
        Label(detail.availability.label, systemImage: detail.availability.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(detail.availability.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(detail.availability.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var distanceRow: some View {
        let meters = distanceMeters ?? 0
        let metersInt = Int(meters.rounded())
        let ready = isBattleReady
        let tint: Color = isBattleRelevant ? (ready ? .green : .orange) : .secondary
        let symbol: String = ready ? "figure.walk" : "location.north.line.fill"
        let statusText: String = {
            guard isBattleRelevant else { return "Away from you" }
            return ready ? "Battle-ready" : "Walk \(metersToBattle)m closer to battle"
        }()

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(metersInt)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary)
                    Text("m")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: ready)
    }

    private func availabilityCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: detail.availability.symbolName)
                .foregroundStyle(detail.availability.tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragTranslation = value.translation.height
                }
            }
            .onEnded(handleDragEnd)
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        let translation = value.translation.height
        let predicted = value.predictedEndTranslation.height
        let downwardSnap: CGFloat = 80
        let downwardDismiss: CGFloat = 130
        let upwardSnap: CGFloat = 60

        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            if currentDetent == .medium && (translation > downwardDismiss || predicted > 180) {
                isPresented = false
            } else if currentDetent == .large && (translation > downwardSnap || predicted > 120) {
                currentDetent = .medium
            } else if translation < -upwardSnap || predicted < -100 {
                currentDetent = .large
            }
            dragTranslation = 0
        }
    }

    @ViewBuilder
    private var destinationToggleButton: some View {
        let hasLocation = userLocation != nil
        let tracking = isCurrentDestination
        let tint = detail.pinType.headerColor
        let title: String = {
            if !hasLocation { return "Location needed" }
            return tracking ? "Tracking" : "Set as Destination"
        }()
        let icon: String = tracking ? "checkmark.circle.fill" : "flag.fill"
        let fill: Color = tracking ? tint.opacity(0.18) : Color(.systemGray6)
        let stroke: Color = tracking ? tint.opacity(0.6) : .clear
        let foreground: Color = tracking ? tint : .primary

        Button {
            onSetDestination?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(fill)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .opacity(hasLocation ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!hasLocation)
        .animation(.easeInOut(duration: 0.2), value: tracking)
    }

    private func actionButton(title: String, fill: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(fill)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func checkProximityAndLaunchAR() {
        if AppConstants.Debug.isMapTeleportTestingEnabled {
            onPrimaryAction()
            return
        }
        guard let userLoc = userLocation else {
            onPrimaryAction()
            return
        }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let pinCL  = CLLocation(latitude: pinCoordinate.latitude, longitude: pinCoordinate.longitude)
        if userCL.distance(from: pinCL) <= AppConstants.AR.collectibleProximityMeters {
            onPrimaryAction()
        } else {
            showProximityAlert = true
        }
    }

    private func openInMaps() {
        let lat = pinCoordinate.latitude
        let lng = pinCoordinate.longitude
        let google = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=walking")
        let apple  = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=w")
        if let url = google, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = apple {
            UIApplication.shared.open(url)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                availability: .active,
                title: "Stadium Spirit Rally",
                dayLabel: "Day 1",
                timeRange: "5:00 PM – 7:00 PM",
                locationName: "Maryland Stadium",
                description: "Show your Terp pride at the opening rally, featuring music and performances.",
                collectibleName: "Stadium Stomper",
                collectibleRarity: "Rare",
                hasARCollectible: true
            ),
            pinCoordinate: CLLocationCoordinate2D(latitude: 38.9889, longitude: -76.9442),
            userLocation: nil,
            isPresented: $isPresented
        )
    }
}
