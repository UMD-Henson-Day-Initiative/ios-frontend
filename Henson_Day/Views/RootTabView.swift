//
//  RootTabView.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// RootTabView.swift

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            MapScreen()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }

            HomeScreen()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            ScheduleScreen()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }

            CollectionScreen()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("Collection")
                }

            ProfileScreen()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
    }
}


#Preview {
    RootTabView()
        .environmentObject(AppState())
}
