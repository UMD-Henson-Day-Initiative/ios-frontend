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
