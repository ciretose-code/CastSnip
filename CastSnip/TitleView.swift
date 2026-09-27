//
//  TitleView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//

import SwiftUI

struct TitleView: View {
    var radius: CGFloat 
    @Binding var title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {        
            Text("Podcast Title")
                .padding(.leading, 3)
                .foregroundColor(.secondary)
                .font(.system(.subheadline).lowercaseSmallCaps())
            TextField("Podcast Title Goes Here", text: $title)
                .textFieldStyle(.plain)
                .accessibilityIdentifier(EditorAccessibility.podcastTitle)
                .accessibilityLabel(EditorAccessibility.podcastTitle)
                .padding(EdgeInsets(top: 4, leading: (radius/2), bottom: 4, trailing: (radius/2)))
                .compatibleTextFieldBorder()
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(Color.primary.opacity(0.2), lineWidth: 1))
        }
    }
}

extension View {
    @ViewBuilder
    func compatibleTextFieldBorder() -> some View {
        if #available(macOS 27, *) {
            self.textFieldStyle(.bordered)
        } else {
            self.textFieldStyle(.roundedBorder)
        }
    }
}

#Preview("Title") {
    
    struct TitleTestView: View {
        @State private var title = "This is a summary"
        var body: some View {
            TitleView(radius: 12, title: $title)
        }
    }
    return TitleTestView().padding()
}
