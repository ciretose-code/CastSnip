//
//  UpdateSettingsView.swift
//  CastSnip
//
//  Settings for GitHub release update checks.
//

import SwiftUI

struct UpdateSettingsView: View {
    @ObservedObject var releaseChecks: ReleaseCheckManager

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { releaseChecks.automaticChecksEnabled },
                        set: { releaseChecks.setAutomaticChecksEnabled($0) }
                    )
                )
                Button(releaseChecks.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                    releaseChecks.checkForUpdates()
                }
                .disabled(releaseChecks.isChecking)
            } header: {
                Text("Updates")
            } footer: {
                Text("CastSet checks GitHub Releases for a newer notarized build and opens the download page when one is available.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360, idealWidth: 420)
        .padding()
    }
}
