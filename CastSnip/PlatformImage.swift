//
//  PlatformImage.swift
//  CastSnip
//

import SwiftUI
import AppKit

typealias PlatformImage = NSImage

extension PlatformImage {
    func toSwiftUIImage() -> Image {
        Image(nsImage: self)
    }

    static func systemImage(named: String, accessibilityDescription: String? = nil) -> PlatformImage? {
        NSImage(systemSymbolName: named, accessibilityDescription: accessibilityDescription)
    }
}
