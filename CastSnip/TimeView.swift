//
//  TimeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/2/24.
//

import SwiftUI

struct TimeView: View {
    @Binding var start: UInt32
    @Binding var end: UInt32
    var radius: CGFloat
    var showHours: Bool
    var maxTime: UInt32 = 0

    @State private var startTextInvalid = false
    @State private var endTextInvalid = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            timeField(label: "Start", value: $start, isInvalid: $startTextInvalid)
            timeField(label: "End", value: $end, isInvalid: $endTextInvalid)
        }
        .frame(minWidth: 168, maxWidth: 188)
    }

    private var rangeIsInvalid: Bool {
        (end != 0 && start >= end) || (maxTime != 0 && (start > maxTime || end > maxTime))
    }

    private func timeField(label: String, value: Binding<UInt32>, isInvalid: Binding<Bool>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .padding(.trailing, 3)
                .foregroundColor(.secondary)
                .font(.system(size: 8).lowercaseSmallCaps())
            EditableTextField(text: textBinding(for: value, isInvalid: isInvalid))
                .font(.system(size: 13)).monospaced()
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke((isInvalid.wrappedValue || rangeIsInvalid) ? Color.red : Color.primary.opacity(0.2), lineWidth: 1)
                )
                .help(Text("\(value.wrappedValue) milliseconds"))
        }
    }

    private func textBinding(for value: Binding<UInt32>, isInvalid: Binding<Bool>) -> Binding<String> {
        Binding(
            get: {
                ID3Parser.toTrackTime(millis: value.wrappedValue, showHours: showHours, showMillis: true)
            },
            set: { newText in
                if let parsed = ID3Parser.parseTrackTime(newText) {
                    isInvalid.wrappedValue = false
                    value.wrappedValue = parsed
                } else {
                    isInvalid.wrappedValue = true
                }
            }
        )
    }
}

#Preview("Time") {
    struct TimeTestView: View {
        @State private var s: UInt32 = 4000
        @State private var e: UInt32 = 7000
        var body: some View {
            TimeView(start: $s, end: $e, radius: 6, showHours: true, maxTime: 17_000)
        }
    }
    return TimeTestView().padding()
}
