//
//  CastSnipApp.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import OSLog

@main
struct CastSnipApp: App {
    
    private let logger = Logger(subsystem: "com.castsnip", category: "App")
    @NSApplicationDelegateAdaptor(CastSnipAppDelegate.self) private var appDelegate
    
    @State var podcastAudioFile = AudioFile()
    @State var fileURL: URL? = Bundle.main.url(forResource: "intro", withExtension: "mp3")
    @State private var pendingOpenURL: URL?
    @State private var showDiscardAlert = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(podcastAudioFile)
                .environment(\.openPodcast, requestOpen(url:))
                .frame(minWidth: 800, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
                .navigationTitle(windowTitle)
                .task {
                    appDelegate.configure(
                        audioFile: podcastAudioFile,
                        currentURL: { fileURL },
                        saveInPlace: { saveInPlace() },
                        saveAs: { saveAs() }
                    )
                    if let url = fileURL {
                        await podcastAudioFile.loadPodcast(from: url)
                    }
                }
                .onChange(of: podcastAudioFile.hasUnsavedChanges) {
                    NSApp.keyWindow?.isDocumentEdited = podcastAudioFile.hasUnsavedChanges
                }
                .alert("Save changes before opening another file?", isPresented: $showDiscardAlert) {
                    Button("Save") {
                        if saveCurrentDocument() {
                            if let pendingOpenURL {
                                applyOpen(pendingOpenURL)
                            }
                        }
                        pendingOpenURL = nil
                    }
                    Button("Don't Save", role: .destructive) {
                        if let pendingOpenURL {
                            applyOpen(pendingOpenURL)
                        }
                        pendingOpenURL = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingOpenURL = nil
                    }
                } message: {
                    Text("Your chapter and metadata edits will be lost if you don't save.")
                }
        }
        .onChange(of: fileURL) {
            if let url = fileURL {
                Task {
                    await podcastAudioFile.loadPodcast(from: url)
                }
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    requestOpenFromPanel()
                }
                .keyboardShortcut("O", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    _ = saveCurrentDocument()
                }
                .keyboardShortcut("S", modifiers: .command)
                Button("Save As...") {
                    _ = saveAs()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }
            
            CommandGroup(before: .help) {
                Button("mostlysecurity.com") {
                    showMostlySecurityWebsite()
                }
            }
        }
        .defaultSize(width: 800, height: 600)
    }

    private var windowTitle: String {
        let name = fileURL?.lastPathComponent ?? "Untitled"
        return podcastAudioFile.hasUnsavedChanges ? "\(name) — Edited" : name
    }

    private func requestOpenFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .wav, .aiff, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestOpen(url: url)
    }

    private func requestOpen(url: URL) {
        if podcastAudioFile.hasUnsavedChanges {
            pendingOpenURL = url
            showDiscardAlert = true
        } else {
            applyOpen(url)
        }
    }

    private func applyOpen(_ url: URL) {
        SecurityScopedBookmarkStore.shared.rememberAndAccess(url)
        fileURL = url
    }

    @discardableResult
    private func saveCurrentDocument() -> Bool {
        if podcastAudioFile.canSaveInPlace(to: fileURL) {
            return saveInPlace()
        }
        return saveAs()
    }

    @discardableResult
    private func saveInPlace() -> Bool {
        guard let url = fileURL else { return saveAs() }
        return write(to: url)
    }

    @discardableResult
    private func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mp3]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "episode.mp3"
        panel.title = "Save Podcast MP3"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        SecurityScopedBookmarkStore.shared.rememberAndAccess(url)
        let didWrite = write(to: url)
        if didWrite {
            fileURL = url
        }
        return didWrite
    }

    @discardableResult
    private func write(to url: URL) -> Bool {
        do {
            try podcastAudioFile.save(to: url)
            NSApp.keyWindow?.isDocumentEdited = false
            return true
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            podcastAudioFile.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func showMostlySecurityWebsite() {
        let address = "https://mostlysecurity.com"
        guard let url = URL(string: address) else {
            logger.error("Invalid URL: \(address)")
            return
        }
        NSWorkspace.shared.open(url)
    }
}

final class CastSnipAppDelegate: NSObject, NSApplicationDelegate {
    private var audioFile: AudioFile?
    private var currentURL: () -> URL? = { nil }
    private var saveInPlace: () -> Bool = { false }
    private var saveAs: () -> Bool = { false }

    func configure(
        audioFile: AudioFile,
        currentURL: @escaping () -> URL?,
        saveInPlace: @escaping () -> Bool,
        saveAs: @escaping () -> Bool
    ) {
        self.audioFile = audioFile
        self.currentURL = currentURL
        self.saveInPlace = saveInPlace
        self.saveAs = saveAs
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let audioFile, audioFile.hasUnsavedChanges else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes you made?"
        alert.informativeText = "Your chapter and metadata edits will be lost if you don't save."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let saved = audioFile.canSaveInPlace(to: currentURL()) ? saveInPlace() : saveAs()
            return saved ? .terminateNow : .terminateCancel
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}
