//  ScreenHeaderBanner.swift
//  Henson_Day
//
//  Shared red → gold hero banner used in place of the native nav bar title,
//  so every tab's header matches Home's full-gradient treatment.

import SwiftUI

struct ScreenHeaderBanner: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            PennantStrip()
                .padding(.top, 44)

            VStack(spacing: 6) {
                Text(title)
                    .font(DS.Typography.display)
                    .foregroundStyle(.white)
                    .tracking(1)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.label)
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(DS.Color.heroGradient)
    }
}

/// Bunting-style pennant banner: a thin string with up to 8 evenly-spaced,
/// downward-pointing triangle flags hanging from it, alternating red/gold.
private struct PennantStrip: View {
    private let triangleWidth: CGFloat = 26
    private let triangleHeight: CGFloat = 24
    private let maxTriangleCount = 8

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DS.Color.gold)
                .frame(height: 2)

            GeometryReader { geometry in
                let gap = max((geometry.size.width - CGFloat(maxTriangleCount) * triangleWidth) / CGFloat(maxTriangleCount + 1), 6)
                HStack(spacing: gap) {
                    ForEach(0..<maxTriangleCount, id: \.self) { index in
                        PennantFlag()
                            .fill(index.isMultiple(of: 2) ? DS.Color.primary : DS.Color.gold)
                            .frame(width: triangleWidth, height: triangleHeight)
                    }
                }
                .padding(.horizontal, gap)
            }
            .frame(height: triangleHeight)
        }
        .frame(height: triangleHeight + 2)
    }
}

/// A downward-pointing pennant flag: flat top edge, apex at the bottom-center.
private struct PennantFlag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Alternating red/gold dot divider — used above/below a page's main content
/// as a whimsical section break.
struct AlternatingDotsDivider: View {
    var count: Int = 9
    var dotSize: CGFloat = 7

    var body: some View {
        HStack(spacing: dotSize + 3) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? DS.Color.primary : DS.Color.gold)
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 0) {
        ScreenHeaderBanner(title: "Schedule")
        AlternatingDotsDivider()
        Spacer()
    }
}
