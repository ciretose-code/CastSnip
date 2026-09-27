//
//  CopyableInfoBadge.swift
//  CastSnip
//

import SwiftUI
import AppKit

struct CopyableInfoBadge: View {
    let label: String
    let value: String
    var minWidth: CGFloat = 0

    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            Text(copied ? "\(label): Copied" : "\(label): \(value)")
                .monospaced()
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .frame(minWidth: minWidth)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlAccentColor).opacity(copied ? 0.25 : 0.12))
        .foregroundStyle(.primary)
        .clipShape(Capsule())
        .help("Copy \(label.lowercased())")
        .accessibilityLabel("\(label) \(value)")
        .accessibilityHint("Copies the value to the clipboard")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}
