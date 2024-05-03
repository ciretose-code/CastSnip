//
//  TimeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/2/24.
//

import SwiftUI

struct TimeView: View {
    var radius: CGFloat

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .trailing) {
                Text("Timestamp").padding(.trailing, 3)
                    .foregroundColor(.secondary)
                    .font(.system(size:8).lowercaseSmallCaps())
                Text("00:00:00").font(.system(size:14)).monospaced()
                    .padding(EdgeInsets(top: 0, leading: 4, bottom: 2, trailing: 4))
            }.background(.white)
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.secondary, lineWidth: 0))
        }.frame(width: 96, height:48)
            
    }
}


#Preview("Time") {
    
    struct TimeTestView: View {
        private var time = "This is a summary"
        var body: some View {
            TimeView(radius: 6)
        }
    }
    return TimeTestView().padding()
}
