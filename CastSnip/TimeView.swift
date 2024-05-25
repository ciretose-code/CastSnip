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
                    .padding(.trailing, 4).help(Text("\(self.start) milliseconds"))
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
        }.frame(minWidth: 128, maxWidth: 128, minHeight:48, maxHeight: 48)
            
    }
    
    private func millisToTrack(_ millis: UInt32) -> String {
        return ID3Parser.toTrackTime(millis: millis, showHours: true, showMillis: true)
    }
    
    private func trackToMillis(_ track: String) -> UInt32 {
        return ID3Parser.trackToMillis(track)
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
//        @State private var s:UInt32 = 71000000
        @State private var s:UInt32 = 72123456
        var body: some View {
            TimeView(start: $s, radius: 6, showHours: true)
        }
    }
    return TimeTestView().padding()
}
