//
//  RootTabView.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// RootTabView.swift

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var modelController: ModelController
    @EnvironmentObject private var tabRouter: TabRouter

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch tabRouter.selectedTab {
                case .home:        HomeScreen()
                case .schedule:    ScheduleScreen()
                case .map:         MapScreen()
                case .collection:  CollectionScreen()
                case .leaderboard: LeaderboardScreen()
                case .profile:     ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HensonBottomBar(selected: $tabRouter.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .alert(
            modelController.userFacingError?.title ?? "Error",
            isPresented: Binding(
                get: { modelController.userFacingError != nil },
                set: { isPresented in
                    if !isPresented {
                        modelController.clearUserFacingError()
                    }
                }
            )
        ) {
            Button("Dismiss", role: .cancel) {
                modelController.clearUserFacingError()
            }
        } message: {
            Text(modelController.userFacingError?.message ?? "")
        }
    }
}

// MARK: - HensonBottomBar

struct HensonBottomBar: View {
    @Binding var selected: AppTab
    @Namespace private var tabNS

    private let tabs: [(tab: AppTab, label: String, icon: String, iconFilled: String)] = [
        (.home,        "Home",       "house",       "house.fill"),
        (.schedule,    "Schedule",   "calendar",    "calendar"),
        (.map,         "Map",        "map",         "map.fill"),
        (.collection,  "Index",      "star.square", "star.square.fill"),
        (.leaderboard, "Board",      "trophy",      "trophy.fill"),
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
            DS.Color.surfaceElevated
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}


#Preview {
    RootTabView()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
        .environmentObject(CameraPermissionManager())
        .environmentObject(WorldAnchorManager())
        .environmentObject(LocationPermissionManager())
}

