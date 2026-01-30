//
//  PlatformImage.swift
//  CastSnip
//
//  Created by Code Review on 1/30/26.
//

import SwiftUI

#if os(iOS)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    /// Convert platform-specific image to SwiftUI Image
    func toSwiftUIImage() -> Image {
        #if os(iOS)
        return Image(uiImage: self)
        #else
        return Image(nsImage: self)
        #endif
    }
    
    /// Create a system symbol image
    static func systemImage(named: String, accessibilityDescription: String? = nil) -> PlatformImage? {
        #if os(iOS)
        return UIImage(systemName: named)
        #else
        return NSImage(systemSymbolName: named, accessibilityDescription: accessibilityDescription)
        #endif
    }
}
