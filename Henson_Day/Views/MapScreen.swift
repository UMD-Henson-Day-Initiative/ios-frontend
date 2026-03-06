//
//  MapScreen.swift
//  Henson_Day
//
//  Created by Jake Frischmann on 2/27/26.
//


// MapScreen.swift

import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var appState: AppState

    // Center roughly on UMD
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.9869, longitude: -76.9426),
        span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Map(initialPosition: .region(region))

                VStack {
                    Spacer()
                    // Temporary button to jump into AR capture
                    NavigationLink {
                        ARCaptureScreen(collectibleId: appState.collectibles.first?.id ?? "demo")
                    } label: {
                        Label("Demo AR Capture", systemImage: "sparkles")
                            .padding()
                            .background(Color("UMDRed"))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Campus Map")
        }
    }
}

#Preview {
    MapScreen()
}
