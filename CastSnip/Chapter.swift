//
//  Chapter.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AppKit

struct Chapter: Identifiable {
    let id = UUID()
    let title: String
    var image: NSImage?
    
    func getImage() -> NSImage {
        if image != nil {
            return image!
        } else {
            return NSImage(systemSymbolName:"photo.badge.plus", accessibilityDescription: "Add Image")!
        }
    }
}
