//  RootTabView.swift
//  Henson_Day
//
//  File Description: This file defines the main tab-based navigation view of the Henson_Day
//  app. It provides a TabView containing the primary sections of the app: Home,
//  Schedule, Map, Collection, and Profile. Each tab is associated with an
//  AppTab enum value to manage selection state. Additionally, it listens
//  for user-facing errors from the ModelController and presents them in an alert.


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
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            ScheduleScreen()
                .tag(AppTab.schedule)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
            
            MapScreen()
                .tag(AppTab.map)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }

            CollectionScreen()
                .tag(AppTab.collection)
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("Collection")
                }

            ProfileScreen()
                .tag(AppTab.profile)
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
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

