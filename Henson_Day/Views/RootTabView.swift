//  RootTabView.swift
//  Henson_Day
//
//  File Description: 5-tab root navigation: Home, Schedule, Map, Leaderboard, Profile.

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var appSession: AppSession

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tabRouter.selectedTab {
                case .home:        HomeScreen()
                case .schedule:    ScheduleScreen()
                case .map:         MapScreen()
                case .leaderboard: LeaderboardScreen()
                case .profile:     ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HensonBottomBar(selected: $tabRouter.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { appSession.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { appSession.errorMessage = nil }
                }
            )
        ) {
            Button("Dismiss", role: .cancel) { appSession.errorMessage = nil }
        } message: {
            Text(appSession.errorMessage ?? "")
        }
    }
}

// MARK: - HensonBottomBar

struct HensonBottomBar: View {
    @Binding var selected: AppTab
    @Namespace private var tabNS

    private let tabs: [(tab: AppTab, label: String, icon: String, iconFilled: String)] = [
        (.home,        "Home",      "house",       "house.fill"),
        (.schedule,    "Schedule",  "calendar",    "calendar"),
        (.map,         "Map",       "map",         "map.fill"),
        (.leaderboard, "Board",     "trophy",      "trophy.fill"),
        (.profile,     "Profile",   "person.crop.circle", "person.crop.circle.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { item in
                let isActive = selected == item.tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = item.tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isActive ? item.iconFilled : item.icon)
                            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                            .symbolRenderingMode(.monochrome)

                        Text(item.label)
                            .font(.system(size: 10, weight: isActive ? .bold : .medium))
                    }
                    .foregroundStyle(isActive ? DS.Color.primary : DS.Color.neutral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isActive {
                            DS.Color.primaryTint
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .matchedGeometryEffect(id: "activeTab", in: tabNS)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .background(
            DS.Color.surfaceElevated
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    RootTabView()
        .environmentObject(TabRouter())
        .environmentObject(AppSession(authManager: AuthManager()))
        .environmentObject(LocationManager())
        .environmentObject(CameraPermissionManager())
}
