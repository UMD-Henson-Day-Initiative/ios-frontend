//  MyCollectionSheet.swift
//  Henson_Day
//
//  File Description: This file defines a SwiftUI sheet view that displays the user's collected
//  AR items. If no items have been collected, an empty-state placeholder is
//  shown with guidance on how to start collecting. Otherwise, the sheet presents
//  a list of collected items including their name, rarity, and location found.
//  The view is embedded in a NavigationStack and includes a close button for dismissal.
//

import SwiftUI

struct MyCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [CollectedItemEntity]

    var body: some View {
        NavigationStack {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No collectibles yet")
                        .font(.headline)
                    Text("Capture items in AR to build your collection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("My Collection")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
            } else {
                List(items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.collectibleName)
                                .font(.headline)
                            Spacer()
                            Text(item.rarity)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("Found at \(item.foundAtTitle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .navigationTitle("My Collection")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }
}
