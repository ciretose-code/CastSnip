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

/// Document actions the editor toolbar can trigger; the app scene owns the implementations.
struct DocumentActions {
    var save: () -> Void = {}
    var encode: () -> Void = {}
    var exportAirchecks: () -> Void = {}
}

private struct DocumentActionsKey: EnvironmentKey {
    static let defaultValue = DocumentActions()
}

extension EnvironmentValues {
    var documentActions: DocumentActions {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }

    var openPodcast: (URL) -> Void {
        get { self[OpenPodcastKey.self] }
        set { self[OpenPodcastKey.self] = newValue }
    }

    var openPodcastPanel: () -> Void {
        get { self[OpenPodcastPanelKey.self] }
        set { self[OpenPodcastPanelKey.self] = newValue }
    }
}
