//  HensonCameraRootView.swift
//  Henson_Day
//
//  File Description: This file defines HensonCameraRootView, the root view for the camera tab.
//  It manages the AR/map primary toggle state and wraps ARMapContainerView in a NavigationStack
//  with the navigation bar hidden for a full-screen AR experience.
//

import SwiftUI

struct HensonCameraRootView: View {
    @State private var isARPrimary = true

    var body: some View {
        NavigationStack {
            ARMapContainerView(isARPrimary: $isARPrimary)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    HensonCameraRootView()
}
