//
//  TimeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/2/24.
//

import SwiftUI

struct TimeView: View {
    var radius: CGFloat
    var start: UInt32
    var end: UInt32
    var showHours: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .trailing) {
                Text("Start").padding(.trailing, 3)
                    .foregroundColor(.secondary)
                    .font(.system(size:8).lowercaseSmallCaps())
                Text(ID3Parser.toTrackTime(millis: start)).font(.system(size:14)).monospaced()
                    .padding(.trailing, 4)
                Text(ID3Parser.toTrackTime(millis:(end-start))).font(.system(size:12)).monospaced()
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                Text("Duration").padding(.trailing, 3)
                    .foregroundColor(.secondary)
                    .font(.system(size:6).lowercaseSmallCaps())
            }.background(.white)
                .cornerRadius(radius)
                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.secondary, lineWidth: 0))
        }.frame(minWidth: 96, minHeight:48)
            
    }
    
}



#Preview("Time") {
    
    struct TimeTestView: View {
        var body: some View {
            TimeView(radius: 6, start: 71000000, end: 72123456, showHours: true)
        }
    }
    return TimeTestView().padding()
}
