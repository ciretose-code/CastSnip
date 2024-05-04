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
                Text(toTrackTime(millis: start)).font(.system(size:14)).monospaced()
                    .padding(.trailing, 4)
                Text(toTrackTime(millis:(end-start))).font(.system(size:12)).monospaced()
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
    
    private func toTrackTime(millis: UInt32, showMillis: Bool = false) -> String {
        let ms = (millis % 1000)
        let sec = millis / 1000
        let s = sec % 60
        let min = sec / 60
        let m = min % 60
        let h = min / 60

        if showMillis {
            if showHours {
                return String(format: "%i:%02i:%02i.%03i", h, m, s, ms)
            } else {
                return String(format: "%i:%02i.%03i", min, s, ms)
            }
        } else {
            if showHours {
                return String(format: "%i:%02i:%02i", h, m, s)
            } else {
                return String(format: "%i:%02i", min, s)
            }
        }
    }


//    private func getStartTime(_ s: UInt32) -> String {
//        print("start: \(start); end: \(end); s: \(s); time: \(toTrackTime(millis: s))")
//        return toTrackTime(millis: s)
//    }
//    
//    private func getDuration(_ d: UInt32) -> String {
//        print("duration: \(d); time: \(toTrackTime(millis: d)); sample: \(toTrackTime(millis: 71000000))")
//        return toTrackTime(millis: d)
//    }
}



#Preview("Time") {
    
    struct TimeTestView: View {
        var body: some View {
            TimeView(radius: 6, start: 71000000, end: 72123456, showHours: true)
        }
    }
    return TimeTestView().padding()
}
