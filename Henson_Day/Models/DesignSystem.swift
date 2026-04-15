// DesignSystem.swift
// Henson_Day
//
// Central design token registry. Every view should reference these constants
// instead of hardcoding values. Global changes become single-line edits.

import SwiftUI

enum DS {

    // MARK: - Color tokens

    enum Color {
        /// Terp Crimson — primary actions, active states, key CTAs
        static let primary = SwiftUI.Color(r: 200, g: 16, b: 46)
        /// Barely-there blush — filled backgrounds behind rarity badges, stat cards
        static let primaryTint = SwiftUI.Color(r: 255, g: 240, b: 240)
        /// Henson Gold — collectible highlights, earned states, first-place
        static let gold = SwiftUI.Color(r: 245, g: 197, b: 24)
        /// Campus Night — body text, card backgrounds in dark contexts
        static let campusNight = SwiftUI.Color(r: 26, g: 26, b: 46)
        /// Warm white app background
        static let surface = SwiftUI.Color(r: 250, g: 250, b: 248)
        /// True white for elevated cards on the warm background
        static let surfaceElevated = SwiftUI.Color.white
        /// Secondary labels, timestamps, empty states
        static let neutral = SwiftUI.Color(r: 138, g: 138, b: 142)

        // Status
        static let statusInProgress = SwiftUI.Color(r: 255, g: 149, b: 0)   // amber
        static let statusCompleted = SwiftUI.Color(r: 52, g: 199, b: 89)    // green

        enum Rarity {
            static let common     = SwiftUI.Color(r: 76,  g: 175, b: 80)
            static let commonTint = SwiftUI.Color(r: 240, g: 255, b: 244)
            static let rare       = SwiftUI.Color(r: 33,  g: 150, b: 243)
            static let rareTint   = SwiftUI.Color(r: 240, g: 247, b: 255)
            static let epic       = SwiftUI.Color(r: 156, g: 39,  b: 176)
            static let epicTint   = SwiftUI.Color(r: 249, g: 240, b: 255)
            static let legendary  = SwiftUI.Color(r: 245, g: 197, b: 24)
            static let legendaryTint = SwiftUI.Color(r: 255, g: 251, b: 240)
        }
    }

    // MARK: - Typography

    enum Typography {
        static let display = Font.system(.largeTitle,   design: .rounded,  weight: .bold)
        static let title1  = Font.system(.title2,       design: .rounded,  weight: .semibold)
        static let title2  = Font.system(.headline,     design: .default,  weight: .semibold)
        static let body    = Font.system(.subheadline,  design: .default,  weight: .regular)
        static let label   = Font.system(.footnote,     design: .default,  weight: .medium)
        static let caption = Font.system(.caption,      design: .default,  weight: .regular)
    }

    // MARK: - Corner radii

    enum Radius {
        static let card:     CGFloat = 20
        static let heroCard: CGFloat = 28
        static let chip:     CGFloat = 999   // pill
        static let statTile: CGFloat = 16
        static let button:   CGFloat = 999   // pill
    }

    // MARK: - Shadow

    enum Shadow {
        static let cardColor  = SwiftUI.Color.black.opacity(0.08)
        static let cardRadius: CGFloat = 12
        static let cardX:     CGFloat = 0
        static let cardY:     CGFloat = 4
    }

    // MARK: - Spacing

    enum Spacing {
        static let screenH:  CGFloat = 20   // horizontal screen margins
        static let cardPad:  CGFloat = 16   // inner card padding
        static let section:  CGFloat = 24   // gap between sections
        static let card:     CGFloat = 12   // gap between cards in a list
    }
}

// MARK: - Rarity helpers

extension String {
    /// Primary color for this rarity string
    func rarityColor() -> SwiftUI.Color {
        switch lowercased() {
        case "legendary": return DS.Color.Rarity.legendary
        case "rare":      return DS.Color.Rarity.rare
        case "epic":      return DS.Color.Rarity.epic
        default:          return DS.Color.Rarity.common
        }
    }

    /// Tinted background for this rarity
    func rarityTint() -> SwiftUI.Color {
        switch lowercased() {
        case "legendary": return DS.Color.Rarity.legendaryTint
        case "rare":      return DS.Color.Rarity.rareTint
        case "epic":      return DS.Color.Rarity.epicTint
        default:          return DS.Color.Rarity.commonTint
        }
    }

    /// SF Symbol name appropriate for this rarity
    func raritySymbol() -> String {
        switch lowercased() {
        case "legendary": return "sparkles"
        case "rare":      return "diamond.fill"
        case "epic":      return "seal.fill"
        default:          return "leaf.fill"
        }
    }
}

// MARK: - Color RGB convenience init

private extension SwiftUI.Color {
    init(r: Double, g: Double, b: Double) {
        self.init(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: 1)
    }
}
