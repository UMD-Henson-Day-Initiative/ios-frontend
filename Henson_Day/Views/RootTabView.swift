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
        TabView(selection: $tabRouter.selectedTab) {

            HomeScreen()
                .tag(AppTab.home)
                .tabItem {
                    Label("Home", systemImage: tabRouter.selectedTab == .home ? "house.fill" : "house")
                }

            ScheduleScreen()
                .tag(AppTab.schedule)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            MapScreen()
                .tag(AppTab.map)
                .tabItem {
                    Label("Map", systemImage: tabRouter.selectedTab == .map ? "map.fill" : "map")
                }

            CollectionScreen()
                .tag(AppTab.collection)
                .tabItem {
                    Label("Collection", systemImage: tabRouter.selectedTab == .collection ? "star.square.fill" : "star.square")
                }

            LeaderboardScreen()
                .tag(AppTab.leaderboard)
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }

            LeaderboardScreen()
                .tag(AppTab.leaderboard)
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }

            ProfileScreen()
                .tag(AppTab.profile)
                .tabItem {
                    Label("Profile", systemImage: tabRouter.selectedTab == .profile ? "person.circle.fill" : "person.circle")
                }
        }
        .tint(DS.Color.primary)
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


#Preview {
    RootTabView()
        .environmentObject(ModelController())
        .environmentObject(TabRouter())
        .environmentObject(CameraPermissionManager())
        .environmentObject(WorldAnchorManager())
        .environmentObject(LocationPermissionManager())
}

