//
//  EpisodeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//

import SwiftUI

struct EpisodeView: View {
    var radius: CGFloat
    @Binding var episode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Episode Title")
                .padding(.leading, 3)
                .foregroundColor(.secondary)
                .font(.system(.subheadline).lowercaseSmallCaps())
            TextField("Episode Title Goes Here", text: $episode)
                .textFieldStyle(.plain)
                .accessibilityIdentifier(EditorAccessibility.episodeTitle)
                .accessibilityLabel(EditorAccessibility.episodeTitle)
                .padding(EdgeInsets(top: 4, leading: (radius/2), bottom: 4, trailing: (radius/2)))
                .compatibleTextFieldBorder()
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(Color.primary.opacity(0.2), lineWidth: 1))
        }
    }
}

#Preview("Episode") {
    
    struct EpisodeTestView: View {
        @State private var episode = "329: This is cool"
        var body: some View {
            EpisodeView(radius: 12, episode: $episode)
        }
    }
    return EpisodeTestView().padding()
}
