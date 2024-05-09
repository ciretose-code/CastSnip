//
//  TimeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/2/24.
//

import SwiftUI

struct TimeView: View {
    @Binding var start: UInt32
//    @Binding var end: UInt32
    var radius: CGFloat
    var showHours: Bool
    var maxTime: UInt32 = 1

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .trailing) {
                Text("Start").padding(.trailing, 3)
                    .foregroundColor(.secondary)
                    .font(.system(size:8).lowercaseSmallCaps())
                EditableTextField(text: getStartTime())
                    .font(.system(size:14)).monospaced()
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing, 4)
//                Text(ID3Parser.toTrackTime(millis: self.end - self.start)).font(.system(size:12)).monospaced()
//                    .foregroundColor(.secondary)
//                    .padding(.trailing, 4)
//                Text("Duration").padding(.trailing, 3)
//                    .foregroundColor(.secondary)
//                    .font(.system(size:6).lowercaseSmallCaps())
                Spacer()
            }
            Spacer()
//            .background(.white)
//                .cornerRadius(radius)
//                .overlay(RoundedRectangle(cornerRadius:radius).stroke(.secondary, lineWidth: 0))
        }.frame(minWidth: 96, maxWidth: 96, minHeight:48, maxHeight: 48)
            
    }
    
    private func millisToTrack(_ millis: UInt32) -> String {
        return ID3Parser.toTrackTime(millis: millis, showHours: true)
    }
    
    private func trackToMillis(_ track: String) -> UInt32 {
        let t = track.components(separatedBy: ":")
        if (t.count == 1) {
            if let seconds = UInt32(t[0]) {
                return seconds * 1000
            } else {
                return 0
            }
        } else if (t.count == 2) {
            if let minutes = UInt32(t[0]) {
                if let seconds = UInt32(t[1]) {
                    return (minutes * 60 * 1000) + (seconds * 1000)
                } else {
                    return (minutes * 60 * 1000)
                }
            } else {
                return 0
            }
        } else if (t.count == 3) {
            if let hours = UInt32(t[0]) {
                if let minutes = UInt32(t[1]) {
                    if let seconds = UInt32(t[2]) {
                        return (hours * 60 * 60 * 1000) + (minutes * 60 * 1000) + (seconds * 1000)
                    } else {
                        return minutes * 60 * 1000
                    }
                } else {
                    return (hours * 60 * 60 * 1000)
                }
            } else {
                return 0
            }
        } else {
            return 0
        }
    }
    
    private func getStartTime() -> Binding<String> {
        return Binding(get: { millisToTrack(self.start) }, set: { self.start = trackToMillis($0) })
    }
    
//    private func getDuration() -> Binding<String> {
//        return Binding(get: { millisToTrack(self.end-self.start)}, set: {self.end = self.start + trackToMillis($0)})
//    }
    
}



#Preview("Time") {
    
    struct TimeTestView: View {
        @State private var s:UInt32 = 71000000
//        @State private var e:UInt32 = 72123456
        var body: some View {
            TimeView(start: $s, radius: 6, showHours: true)
        }
    }
    return TimeTestView().padding()
}
