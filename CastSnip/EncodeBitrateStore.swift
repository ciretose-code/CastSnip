//
//  EncodeBitrateStore.swift
//  CastSnip
//
//  CBR bitrate choices for Encode to MP3, persisted across launches.
//

import AppKit
import Foundation
import Observation

enum EncodeBitrate: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case kbps64 = 64
    case kbps96 = 96
    case kbps128 = 128
    case kbps192 = 192

    /// Forecast-class default; used when preference is missing or invalid.
    static let podcastDefault = kbps192

    var id: Int { rawValue }

    var menuTitle: String { "\(rawValue) kbps" }

    static func resolved(_ raw: Int) -> EncodeBitrate {
        EncodeBitrate(rawValue: raw) ?? .podcastDefault
    }
}

@Observable
final class EncodeBitrateStore {
    static let shared = EncodeBitrateStore()
    static let defaultsKey = "encodeBitrateKbps"

    private let defaults: UserDefaults
    var bitrate: EncodeBitrate {
        didSet { defaults.set(bitrate.rawValue, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.defaultsKey) == nil {
            bitrate = .podcastDefault
        } else {
            bitrate = EncodeBitrate.resolved(defaults.integer(forKey: Self.defaultsKey))
        }
    }

    struct AccessoryControls {
        let popup: NSPopUpButton
        let tagsCheckbox: NSButton
    }

    /// Bitrate popup + ID3 checkbox for the Encode save panel.
    @discardableResult
    func attachAccessory(to panel: NSSavePanel, tagging: ID3TaggingStore) -> AccessoryControls {
        let label = NSTextField(labelWithString: "Bitrate:")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.setContentHuggingPriority(.required, for: .horizontal)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        for option in EncodeBitrate.allCases {
            popup.addItem(withTitle: option.menuTitle)
            popup.lastItem?.tag = option.rawValue
        }
        popup.selectItem(withTag: bitrate.rawValue)
        popup.toolTip = "Constant bitrate for the encoded MP3"
        popup.setContentCompressionResistancePriority(.required, for: .horizontal)

        let bitrateRow = NSStackView(views: [label, popup])
        bitrateRow.orientation = .horizontal
        bitrateRow.alignment = .centerY
        bitrateRow.spacing = 8

        let checkbox = tagging.makeCheckbox()
        checkbox.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Vertical layout + explicit width: NSSavePanel otherwise clamps a single
        // horizontal row between the separator lines and squashes the popup.
        let stack = NSStackView(views: [bitrateRow, checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        panel.accessoryView = stack

        return AccessoryControls(popup: popup, tagsCheckbox: checkbox)
    }

    func apply(from popup: NSPopUpButton) {
        bitrate = EncodeBitrate.resolved(popup.selectedTag())
    }
}
