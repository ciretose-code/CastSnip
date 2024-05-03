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
                .padding(EdgeInsets(top: 4, leading: (radius/2), bottom: 4, trailing: (radius/2)))
                .textFieldStyle(.roundedBorder)
                .background(.white)
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.secondary, lineWidth: 1))
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
