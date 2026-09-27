//
//  OpenPodcastEnvironment.swift
//  CastSnip
//

import SwiftUI

private struct OpenPodcastKey: EnvironmentKey {
    static let defaultValue: (URL) -> Void = { _ in }
}

extension EnvironmentValues {
    var openPodcast: (URL) -> Void {
        get { self[OpenPodcastKey.self] }
        set { self[OpenPodcastKey.self] = newValue }
    }
}
