//
//  SummaryView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//


import SwiftUI

struct SummaryView: View {
    var radius: CGFloat
    @Binding var summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Summary")
                .padding(.leading, 3)
                .foregroundColor(.secondary)
                .font(.system(.subheadline).lowercaseSmallCaps())
            
            TextEditor(text: $summary)
                .padding(EdgeInsets(top: (radius/1), leading: 0, bottom: (radius/2), trailing: 4))
                .background(.white)
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.secondary, lineWidth: 1))
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        //.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}


#Preview("Summary") {
    
    struct SummaryTestView: View {
        @State private var summary = "This is a summary"
        var body: some View {
            SummaryView(radius: 12, summary: $summary)
        }
    }
    return SummaryTestView().padding()
}
