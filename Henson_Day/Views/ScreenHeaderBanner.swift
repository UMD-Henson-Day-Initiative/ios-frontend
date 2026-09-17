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
        .padding(.top, 56)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(DS.Color.heroGradient)
    }
}

#Preview {
    ScreenHeaderBanner(title: "Schedule")
}
