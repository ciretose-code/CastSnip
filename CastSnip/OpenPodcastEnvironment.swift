//
//  OpenPodcastEnvironment.swift
//  CastSnip
//

import SwiftUI

private struct OpenPodcastKey: EnvironmentKey {
    static let defaultValue: (URL) -> Void = { _ in }
}

private struct OpenPodcastPanelKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openPodcast: (URL) -> Void {
        get { self[OpenPodcastKey.self] }
        set { self[OpenPodcastKey.self] = newValue }
    }

    var openPodcastPanel: () -> Void {
        get { self[OpenPodcastPanelKey.self] }
        set { self[OpenPodcastPanelKey.self] = newValue }
    }
}
