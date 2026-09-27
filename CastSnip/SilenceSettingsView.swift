//
//  SilenceSettingsView.swift
//  CastSnip
//
//  Settings for the Save / Encode accidental-silence warning.
//

import SwiftUI

struct SilenceSettingsView: View {
    static let durationLabel = "Minimum silence duration"
    static let thresholdLabel = "Silence threshold"
    static let durationUnit = "seconds"
    static let thresholdUnit = "dBFS"

    @Bindable var store: SilenceSettingsStore

    init(store: SilenceSettingsStore = .shared) {
        self.store = store
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(Self.durationLabel) {
                    TextField(Self.durationUnit, value: $store.durationSeconds, format: .number.precision(.fractionLength(1)))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                    Text(Self.durationUnit)
                        .foregroundStyle(.secondary)
                }
                LabeledContent(Self.thresholdLabel) {
                    TextField(Self.thresholdUnit, value: $store.thresholdDb, format: .number.precision(.fractionLength(0)))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                    Text(Self.thresholdUnit)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Silence warning")
            } footer: {
                Text("Save and Encode warn when a gap stays below this level for at least this long.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, idealWidth: 420)
        .padding()
    }
}
