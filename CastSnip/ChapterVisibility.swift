//
//  ChapterVisibility.swift
//  CastSnip
//

import Foundation

enum ChapterVisibility {
    static func apply(tocChildIDs: [String]?, to chapters: [Chapter]) {
        guard let tocChildIDs, !tocChildIDs.isEmpty else { return }
        for chapter in chapters {
            guard !chapter.elementID.isEmpty else { continue }
            chapter.isHidden = !tocChildIDs.contains(chapter.elementID)
        }
    }
}
