//
//  Chapter.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AVFoundation

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    var marker: CGFloat = 0.0
    var image: NSImage? = nil
    
    func getImage() -> NSImage {
        if image != nil {
            return image!
        } else {
            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
        }
    }
}
