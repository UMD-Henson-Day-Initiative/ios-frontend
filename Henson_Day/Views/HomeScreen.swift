//  HomeScreen.swift
//  Henson_Day
//
//  Static welcome/explainer screen — no backend data needed here, just an
//  overview of what each tab does for a first-time user.

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var tabRouter: TabRouter

    private let features: [HomeFeature] = [
        HomeFeature(
            icon: "calendar",
            title: "Schedule",
            description: "Every Henson Day event, with the day and time it happens.",
            tab: .schedule
        ),
        HomeFeature(
            icon: "map.fill",
            title: "Map",
            description: "See every event's location on the map. Tap a pin for details, then Navigate opens Apple Maps to walk you there.",
            tab: .map
        ),
        HomeFeature(
            icon: "camera.viewfinder",
            title: "Collect Coins",
            description: "Once you're within 0.1 miles of an event, the Collect button unlocks — it opens your camera so you can grab the coin and earn points.",
            tab: .map
        ),
        HomeFeature(
            icon: "trophy.fill",
            title: "Leaderboard",
            description: "See the top 10 players on campus by total points.",
            tab: .leaderboard
        ),
        HomeFeature(
            icon: "person.crop.circle.fill",
            title: "Profile",
            description: "Track your points, events attended, and your account info.",
            tab: .profile
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.section) {
                        header

                        VStack(spacing: DS.Spacing.card) {
                            ForEach(features) { feature in
                                FeatureCard(feature: feature) {
                                    tabRouter.selectedTab = feature.tab
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.screenH)
                    }
                    .padding(.bottom, DS.Spacing.section)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("HENSON DAY")
                .font(DS.Typography.display)
                .foregroundStyle(.white)
                .tracking(2)

            Text("University of Maryland · Campus Scavenger Hunt")
                .font(DS.Typography.label)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Spacing.screenH)
        .padding(.top, 56)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [DS.Color.primary, DS.Color.primary.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct HomeFeature: Identifiable {
    let icon: String
    let title: String
    let description: String
    let tab: AppTab

    var id: String { title }
}

private struct FeatureCard: View {
    let feature: HomeFeature
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.card) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous)
                        .fill(DS.Color.primaryTint)
                        .frame(width: 48, height: 48)
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Color.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Color.campusNight)
                    Text(feature.description)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeScreen()
        .environmentObject(TabRouter())
}
