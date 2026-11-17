//
//  LegacyListScreen.swift
//  The original 20-row proof-of-concept list. Rows 7, 14 and 19 carry
//  deliberate accessibility issues. Kept for the basic scroll-coverage test.
//

import SwiftUI

struct LegacyListScreen: View {
    private let rowCount = 20

    var body: some View {
        List(1...rowCount, id: \.self) { index in
            HStack {
                rowTitle(index)
                Spacer()
                rowAction(index)
            }
            .frame(minHeight: 72)
        }
        .accessibilityIdentifier("itemList")
        .navigationTitle("Items")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func rowTitle(_ index: Int) -> some View {
        if index == 7 {
            // SEEDED: low contrast. Both colours are pinned so the ratio holds in any appearance.
            Text("Row \(index)")
                .foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.62))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.75, green: 0.75, blue: 0.75))
                .accessibilityIdentifier("row_\(index)")
        } else {
            Text("Row \(index)")
                .accessibilityIdentifier("row_\(index)")
        }
    }

    @ViewBuilder
    private func rowAction(_ index: Int) -> some View {
        if index == 14 {
            // SEEDED: no accessible description.
            Button(action: {}) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("row_\(index)_action")
        } else if index == 19 {
            // SEEDED: tiny hit region
            Button(action: {}) {
                Image(systemName: "trash")
                    .font(.system(size: 8))
            }
            .buttonStyle(.borderless)
            .frame(width: 10, height: 10)
            .contentShape(Rectangle())
            .accessibilityLabel("Delete")
            .accessibilityIdentifier("row_\(index)_action")
        } else {
            Button("Open") {}
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("row_\(index)_action")
        }
    }
}
