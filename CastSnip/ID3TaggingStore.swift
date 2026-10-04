//
//  ID3TaggingStore.swift
//  CastSnip
//
//  Save and encode write every modeled ID3 frame unless the user turns tags off.
//

import AppKit
import Foundation
import Observation

@Observable
final class ID3TaggingStore {
    static let shared = ID3TaggingStore()
    static let defaultsKey = "includeID3Tags"
    static let checkboxTitle = "Include ID3 tags"
    static let checkboxHelp = "Write show info, chapters, and artwork"

    private let defaults: UserDefaults
    var includeTags: Bool {
        didSet { defaults.set(includeTags, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.defaultsKey) == nil {
            includeTags = true
        } else {
            includeTags = defaults.bool(forKey: Self.defaultsKey)
        }
    }

    func makeCheckbox() -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: Self.checkboxTitle, target: nil, action: nil)
        checkbox.state = includeTags ? .on : .off
        checkbox.toolTip = Self.checkboxHelp
        return checkbox
    }

    @discardableResult
    func attachCheckbox(to panel: NSSavePanel) -> NSButton {
        let checkbox = makeCheckbox()
        panel.accessoryView = checkbox
        return checkbox
    }

    func apply(from checkbox: NSButton) {
        includeTags = checkbox.state == .on
    }
}
