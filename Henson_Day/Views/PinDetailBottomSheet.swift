//  PinDetailBottomSheet.swift
//  Henson_Day
//
//  Bottom sheet shown when a map pin is tapped. Shows the event's info, a
//  Navigate button (opens Apple Maps with the event as destination), and a
//  Collect button that's only enabled within AppConstants.Collect.radiusMeters
//  of the event. Supports drag-to-resize/dismiss.

import SwiftUI
import CoreLocation
import MapKit

struct PinDetailBottomSheet: View {
    let event: EventItem
    var userLocation: CLLocationCoordinate2D? = nil
    @Binding var isPresented: Bool
    var onCollect: () -> Void = {}

    @State private var dragTranslation: CGFloat = 0
    @State private var currentDetent: SheetDetent = .medium
    @State private var showTooFarAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isOverscrollDragging = false

    private enum SheetDetent {
        case medium
        case large

        func height(in geometry: GeometryProxy) -> CGFloat {
            switch self {
            case .medium: return max(geometry.size.height * 0.55, 380)
            case .large: return geometry.size.height * 0.9
            }
        }
    }

    private var pinCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
    }

    private var distanceMeters: CLLocationDistance? {
        straightLineDistance(from: userLocation, to: pinCoordinate)
    }

    private var isCloseEnoughToCollect: Bool {
        guard let d = distanceMeters else { return false }
        return d <= AppConstants.Collect.radiusMeters
    }

    private var metersToCollect: Int {
        guard let d = distanceMeters else { return 0 }
        return max(0, Int((d - AppConstants.Collect.radiusMeters).rounded()))
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        guard let endTime = event.endTime else { return formatter.string(from: event.startTime) }
        return "\(formatter.string(from: event.startTime)) – \(formatter.string(from: endTime))"
    }

    private var dismissDragOpacity: Double {
        let progress = min(1.0, max(0, Double(dragTranslation)) / 220.0)
        return 1.0 - progress * 0.85
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
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.22))
                    .frame(width: 56, height: 56)
                Image(systemName: "star.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(timeRangeText) • \(event.locationName)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [DS.Color.primary, DS.Color.primary.opacity(0.82)],
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

                    Text(event.description)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    pointsCard

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

    private var pointsCard: some View {
        HStack(spacing: 6) {
            Image(systemName: event.collected ? "checkmark.seal.fill" : "circle.grid.cross.fill")
                .foregroundStyle(DS.Color.gold)
            Text(event.collected ? "Coin already collected" : "Worth +\(event.points) points")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var distanceRow: some View {
        let meters = distanceMeters ?? 0
        let metersInt = Int(meters.rounded())
        let ready = isCloseEnoughToCollect
        let tint: Color = ready ? .green : .orange
        let symbol: String = ready ? "figure.walk" : "location.north.line.fill"
        let statusText: String = ready ? "Close enough to collect" : "Walk \(metersToCollect)m closer to collect"

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

    private var actionFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if !event.collected {
                        actionButton(
                            title: "Collect",
                            fill: isCloseEnoughToCollect ? DS.Color.primary : Color(.systemGray5),
                            foreground: isCloseEnoughToCollect ? .white : .secondary
                        ) {
                            if isCloseEnoughToCollect {
                                onCollect()
                            } else {
                                showTooFarAlert = true
                            }
                        }
                    }

                    actionButton(title: "Navigate", fill: Color(.systemGray6), foreground: .primary) {
                        openInAppleMaps()
                    }
                }
                .alert("Not close enough yet", isPresented: $showTooFarAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Get within 0.1 miles of \(event.locationName) to collect its coin.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(Color(.systemBackground))
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

    private var overscrollDismissGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
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

    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: pinCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.locationName
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
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
            event: EventItem(
                id: "1",
                title: "Stadium Spirit Rally",
                description: "Show your Terp pride at the opening rally, featuring music and performances.",
                locationName: "Maryland Stadium",
                latitude: 38.9889,
                longitude: -76.9442,
                startTime: .now,
                endTime: .now.addingTimeInterval(7200),
                points: 25,
                collected: false
            ),
            userLocation: nil,
            isPresented: $isPresented
        )
    }
}
