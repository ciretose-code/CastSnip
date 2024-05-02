//
//  TitleView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//

import SwiftUI

struct TitleView: View {
    var title: String
    @State var titleField: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {        
            Text("Title")
                .font(.system(.subheadline).lowercaseSmallCaps())
            TextField(title, text: $titleField)
                .textFieldStyle(.roundedBorder)
        }
    }
}
