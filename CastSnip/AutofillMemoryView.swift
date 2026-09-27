//
//  AutofillMemoryView.swift
//  CastSnip
//

import SwiftUI
import AppKit
import Observation

enum AutofillMemoryCopy {
    static let browseMenu = "Browse Autofill Memory…"
    static let windowTitle = "Autofill Memory"
    static let showsSection = "Shows"
    static let chaptersSection = "Chapters"
    static let delete = "Delete"
    static let clearAll = "Clear All"
    static let done = "Done"
    static let emptyShows = "No remembered shows"
    static let emptyChapters = "No remembered chapters"
    static let noSelection = "Select a show or chapter to preview"
}

enum AutofillMemorySelection: Hashable {
    case show(String)
    case chapter(String)
}

@Observable
final class AutofillMemoryBrowser {
    private let store: ShowAutofillStore
    var selection: AutofillMemorySelection?

    init(store: ShowAutofillStore) {
        self.store = store
    }

    var shows: [StoredShowAutofill] { store.storedShows() }
    var chapters: [StoredChapterAutofill] { store.storedChapters() }

    var selectedShow: StoredShowAutofill? {
        guard case .show(let prefix) = selection else { return nil }
        return shows.first { $0.prefix == prefix }
    }

    var selectedChapter: StoredChapterAutofill? {
        guard case .chapter(let title) = selection else { return nil }
        return chapters.first { $0.title == title }
    }

    func deleteSelected() {
        switch selection {
        case .show(let prefix):
            store.deleteShow(prefix: prefix)
        case .chapter(let title):
            store.deleteChapter(title: title)
        case nil:
            return
        }
        selection = nil
    }

    func clearAll() {
        store.clear()
        selection = nil
    }
}

struct AutofillMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browser: AutofillMemoryBrowser

    init(store: ShowAutofillStore = .shared) {
        _browser = State(initialValue: AutofillMemoryBrowser(store: store))
    }

    var body: some View {
        NavigationStack {
            memoryBrowser
        }
    }

    private var memoryBrowser: some View {
        VStack(spacing: 0) {
            HSplitView {
                memoryList
                    .frame(minWidth: 200)
                preview
                    .frame(minWidth: 220)
            }
            Divider()
            HStack {
                Button(AutofillMemoryCopy.delete) {
                    browser.deleteSelected()
                }
                .disabled(browser.selection == nil)
                Button(AutofillMemoryCopy.clearAll, role: .destructive) {
                    browser.clearAll()
                }
                .disabled(browser.shows.isEmpty && browser.chapters.isEmpty)
                Spacer()
                Button(AutofillMemoryCopy.done) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 560, minHeight: 380)
        .navigationTitle(AutofillMemoryCopy.windowTitle)
    }

    private var memoryList: some View {
        List(selection: $browser.selection) {
            Section(AutofillMemoryCopy.showsSection) {
                if browser.shows.isEmpty {
                    Text(AutofillMemoryCopy.emptyShows)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(browser.shows) { show in
                        LabeledContent(show.prefix, value: show.title)
                            .tag(AutofillMemorySelection.show(show.prefix))
                    }
                }
            }
            Section(AutofillMemoryCopy.chaptersSection) {
                if browser.chapters.isEmpty {
                    Text(AutofillMemoryCopy.emptyChapters)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(browser.chapters) { chapter in
                        Text(chapter.title)
                            .tag(AutofillMemorySelection.chapter(chapter.title))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let show = browser.selectedShow {
                VStack(spacing: 12) {
                    previewImage(show.artwork)
                    Text(show.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(show.prefix)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let chapter = browser.selectedChapter {
                VStack(spacing: 12) {
                    previewImage(chapter.image)
                    Text(chapter.title)
                        .font(.headline)
                    if let url = chapter.url {
                        Text(url)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                Text(AutofillMemoryCopy.noSelection)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func previewImage(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 160)
                .clipShape(.rect(cornerRadius: 6))
        }
    }
}
