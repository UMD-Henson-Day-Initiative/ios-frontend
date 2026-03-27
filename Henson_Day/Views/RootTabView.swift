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
}
