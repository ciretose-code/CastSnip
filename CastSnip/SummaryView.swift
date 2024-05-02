//
//  SummaryView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//


import SwiftUI

struct SummaryView: View {
    var summary: String
    @State var summaryField: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Summary")
                .font(.system(.subheadline).lowercaseSmallCaps())
            TextField(summary, text: $summaryField, axis: .vertical)
                .lineLimit(4)
                .textFieldStyle(.roundedBorder)
        }
    }
}
