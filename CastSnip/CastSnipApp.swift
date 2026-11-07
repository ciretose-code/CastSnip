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

/// Open request for the editor. `reloadID` increments even when `fileURL` is unchanged
/// so reopening the current file loads it from disk again.
struct DocumentOpenState: Equatable {
    var fileURL: URL?
    var reloadID: Int = 0

    mutating func open(_ url: URL) {
        fileURL = url
        reloadID += 1
    }
}

@main
struct CastSnipApp: App {
    
    private let logger = Logger(subsystem: "com.castsnip", category: "App")
    @NSApplicationDelegateAdaptor(CastSnipAppDelegate.self) private var appDelegate
    
    @State var podcastAudioFile = AudioFile()
    @State var fileURL: URL?
    /// Bumped on every open, including the file that is already open, so the scene reloads from disk.
    @State private var documentReloadID = 0
    @State private var recentFiles = RecentFilesStore.shared
    @State private var tagging = ID3TaggingStore.shared
    @State private var encodeBitrate = EncodeBitrateStore.shared
    @State private var silenceSettings = SilenceSettingsStore.shared
    @StateObject private var releaseChecks = ReleaseCheckManager()
    @State private var pendingAction: PendingDocumentAction?
    @State private var showDiscardAlert = false
    @State private var showShortcutsHelp = false
    @FocusedValue(\.editorCommands) private var editorCommands
    @State private var showAutofillBrowser = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(podcastAudioFile)
                .environment(\.openPodcast, requestOpen(url:))
                .environment(\.openPodcastPanel, requestOpenFromPanel)
                .environment(\.documentActions, DocumentActions(
                    save: { _ = saveCurrentDocument() },
                    encode: encodeToMP3,
                    exportAirchecks: exportAirchecks
                ))
                .frame(minWidth: 900, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
                .navigationTitle(windowTitle)
                .task {
                    appDelegate.configure(
                        audioFile: podcastAudioFile,
                        currentURL: { fileURL },
                        saveInPlace: { saveInPlace() },
                        saveAs: { saveAs() }
                    )
                    releaseChecks.startAutomaticChecks()
                    if let url = UITestLaunchArguments().resolvedOpenURL() {
                        applyOpen(url)
                    }
                    if let url = fileURL {
                        await podcastAudioFile.loadPodcast(from: url)
                    }
                }
                .onChange(of: podcastAudioFile.hasUnsavedChanges) {
                    NSApp.keyWindow?.isDocumentEdited = podcastAudioFile.hasUnsavedChanges
                }
                .onChange(of: fileURL) {
                    NSApp.keyWindow?.representedURL = fileURL
                }
                .alert(discardAlertTitle, isPresented: $showDiscardAlert) {
                    Button("Save") {
                        if saveCurrentDocument(), let pendingAction {
                            perform(pendingAction)
                        }
                        pendingAction = nil
                    }
                    Button("Don't Save", role: .destructive) {
                        if let pendingAction {
                            perform(pendingAction)
                        }
                        pendingAction = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingAction = nil
                    }
                } message: {
                    Text("Your chapter and metadata edits will be lost if you don't save.")
                }
                .alert("Keyboard Shortcuts", isPresented: $showShortcutsHelp) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(KeyboardShortcutsHelp.text)
                }
                .sheet(isPresented: $showAutofillBrowser) {
                    AutofillMemoryView()
                }
        }
        .onChange(of: documentReloadID) {
            guard documentReloadID > 0, let url = fileURL else { return }
            Task {
                await podcastAudioFile.loadPodcast(from: url)
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button(releaseChecks.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                    releaseChecks.checkForUpdates()
                }
                .disabled(releaseChecks.isChecking)
            }

            CommandGroup(replacing: .newItem) {
                Button("New") {
                    requestClose()
                }
                Button("Open...") {
                    requestOpenFromPanel()
                }
                .keyboardShortcut("O", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Menu("Open Recent") {
                    if recentFiles.paths().isEmpty {
                        Button("No Recent Files") {}
                            .disabled(true)
                    } else {
                        ForEach(recentFiles.urls(), id: \.path) { url in
                            Button(url.lastPathComponent) {
                                requestOpenRecent(url)
                            }
                        }
                        Divider()
                        Button("Clear Menu") {
                            recentFiles.clear()
                        }
                    }
                }
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    _ = saveCurrentDocument()
                }
                .keyboardShortcut("S", modifiers: .command)
                .disabled(fileURL == nil && !podcastAudioFile.hasUnsavedChanges)
                Button("Save As...") {
                    _ = saveAs()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
                Toggle(ID3TaggingStore.checkboxTitle, isOn: Bindable(tagging).includeTags)
                    .help(ID3TaggingStore.checkboxHelp)
                Button("Encode to MP3…") {
                    encodeToMP3()
                }
                .disabled(fileURL == nil && podcastAudioFile.podcast.url == nil)
                Button("Export Chapter Clips…") {
                    exportAirchecks()
                }
                .disabled(fileURL == nil && podcastAudioFile.podcast.url == nil)
                Button("Close") {
                    requestClose()
                }
                .keyboardShortcut("W", modifiers: .command)
                .disabled(fileURL == nil && !podcastAudioFile.hasUnsavedChanges)
            }

            CommandGroup(before: .toolbar) {
                Button("Zoom In") { editorCommands?.zoomIn?() }
                    .keyboardShortcut("=", modifiers: .command)
                    .disabled(editorCommands?.zoomIn == nil)
                Button("Zoom Out") { editorCommands?.zoomOut?() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(editorCommands?.zoomOut == nil)
                Button("Zoom to Fit") { editorCommands?.zoomToFit?() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(editorCommands?.zoomToFit == nil)
                Divider()
                Button(editorCommands?.isInspectorShown == false ? "Show Inspector" : "Hide Inspector") {
                    editorCommands?.toggleInspector()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(editorCommands == nil)
                Divider()
            }

            CommandMenu("Chapter") {
                Button("Add Chapter at Playhead") {
                    editorCommands?.addChapter()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(editorCommands == nil)
                Button("Set Start to Playhead") {
                    editorCommands?.setStartToPlayhead?()
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(editorCommands?.setStartToPlayhead == nil)
                Divider()
                Button("Previous Chapter") {
                    podcastAudioFile.selectNeighbor(going: .previous)
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(podcastAudioFile.podcast.chapters.isEmpty)
                Button("Next Chapter") {
                    podcastAudioFile.selectNeighbor(going: .next)
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(podcastAudioFile.podcast.chapters.isEmpty)
            }

            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    showShortcutsHelp = true
                }
                Button("Open Sample Episode") {
                    openSampleEpisode()
                }
                Button("CastSet Website") {
                    openCastSnipWebsite()
                }
                Button(AutofillMemoryCopy.browseMenu) {
                    showAutofillBrowser = true
                }
            }
        }
        .defaultSize(width: 1180, height: 760)

        Settings {
            TabView {
                SilenceSettingsView(store: silenceSettings)
                    .tabItem {
                        Label("Silence", systemImage: "speaker.slash")
                    }
                UpdateSettingsView(releaseChecks: releaseChecks)
                    .tabItem {
                        Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
            }
            .frame(minWidth: 420, minHeight: 240)
        }
    }

    private enum PendingDocumentAction {
        case open(URL)
        case close
    }

    private var windowTitle: String {
        guard let name = fileURL?.lastPathComponent else { return "CastSet" }
        return podcastAudioFile.hasUnsavedChanges ? "\(name) — Edited" : name
    }

    private var discardAlertTitle: String {
        switch pendingAction {
        case .close:
            return "Save changes before closing?"
        default:
            return "Save changes before opening another file?"
        }
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
        request(.open(url))
    }

    private func requestOpenRecent(_ url: URL) {
        if let resolved = SecurityScopedBookmarkStore.shared.resolveAndAccess(path: url.path) {
            requestOpen(url: resolved)
        } else {
            requestOpen(url: url)
        }
    }

    private func requestClose() {
        request(.close)
    }

    private func request(_ action: PendingDocumentAction) {
        if podcastAudioFile.hasUnsavedChanges {
            pendingAction = action
            showDiscardAlert = true
        } else {
            perform(action)
        }
    }

    private func perform(_ action: PendingDocumentAction) {
        switch action {
        case .open(let url):
            applyOpen(url)
        case .close:
            applyClose()
        }
    }

    private func applyOpen(_ url: URL) {
        SecurityScopedBookmarkStore.shared.rememberAndAccess(url)
        RecentFilesStore.shared.remember(url)
        var state = DocumentOpenState(fileURL: fileURL, reloadID: documentReloadID)
        state.open(url)
        fileURL = state.fileURL
        documentReloadID = state.reloadID
        NSApp.keyWindow?.representedURL = url
    }

    private func openSampleEpisode() {
        guard let url = SampleEpisode.url() else { return }
        requestOpen(url: url)
    }

    private func applyClose() {
        fileURL = nil
        podcastAudioFile.closeDocument()
        NSApp.keyWindow?.representedURL = nil
        NSApp.keyWindow?.isDocumentEdited = false
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
        guard confirmSilenceOrContinue() else { return false }
        return write(to: url)
    }

    @discardableResult
    private func saveAs() -> Bool {
        let uiTest = UITestLaunchArguments()
        if !uiTest.isActive {
            guard confirmSilenceOrContinue() else { return false }
        }
        if let dest = uiTest.saveAsURL {
            return writeSaveDestination(dest)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mp3]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "episode.mp3"
        panel.title = "Save Podcast MP3"
        let tagsCheckbox = tagging.attachCheckbox(to: panel)
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        tagging.apply(from: tagsCheckbox)
        return writeSaveDestination(url)
    }

    @discardableResult
    private func writeSaveDestination(_ url: URL) -> Bool {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        SecurityScopedBookmarkStore.shared.rememberAndAccess(url)
        let didWrite = write(to: url)
        if didWrite {
            RecentFilesStore.shared.remember(url)
            fileURL = url
        }
        return didWrite
    }

    @discardableResult
    private func write(to url: URL) -> Bool {
        do {
            try podcastAudioFile.save(to: url, includeTags: tagging.includeTags)
            NSApp.keyWindow?.isDocumentEdited = false
            return true
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            podcastAudioFile.errorMessage = error.localizedDescription
            return false
        }
    }

    /// Warns on long accidental gaps. Detection failure logs and continues.
    private func confirmSilenceOrContinue() -> Bool {
        guard let message = SilenceDetector.warningMessage(for: podcastAudioFile, settings: silenceSettings) else {
            return true
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Long silence detected"
        alert.informativeText = message
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func encodeToMP3() {
        guard let source = fileURL ?? podcastAudioFile.podcast.url else { return }
        let uiTest = UITestLaunchArguments()
        if !uiTest.isActive {
            guard confirmSilenceOrContinue() else { return }
        }

        if let dest = uiTest.encodeURL {
            beginEncode(from: source, to: dest)
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mp3]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = source.deletingPathExtension().appendingPathExtension("mp3").lastPathComponent
        panel.title = "Encode to MP3"
        let accessory = encodeBitrate.attachAccessory(to: panel, tagging: tagging)
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        encodeBitrate.apply(from: accessory.popup)
        tagging.apply(from: accessory.tagsCheckbox)
        beginEncode(from: source, to: dest, bitrateKbps: encodeBitrate.bitrate.rawValue)
    }

    private func beginEncode(from source: URL, to dest: URL, bitrateKbps: Int = 192) {
        let directory = dest.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        SecurityScopedBookmarkStore.shared.rememberAndAccess(dest)
        Task { @MainActor in
            await performEncode(from: source, to: dest, bitrateKbps: bitrateKbps)
        }
    }

    private func performEncode(from source: URL, to dest: URL, bitrateKbps: Int) async {
        let rate = EncodeBitrate.resolved(bitrateKbps)
        let alert = NSAlert()
        alert.messageText = "Encoding…"
        alert.informativeText = "Creating a podcast file (\(rate.rawValue) kbps CBR stereo MP3 via in-process LAME)."
        alert.window.setAccessibilityIdentifier(EditorAccessibility.encoding)
        let bar = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 240, height: 16))
        bar.minValue = 0
        bar.maxValue = 1
        bar.isIndeterminate = false
        bar.doubleValue = 0
        alert.accessoryView = bar

        let window = NSApp.keyWindow
        if let window {
            alert.beginSheetModal(for: window) { _ in }
        }

        do {
            let written = try await PodcastEncoder.encode(
                from: source,
                to: dest,
                tagging: podcastAudioFile.podcast,
                includeTags: tagging.includeTags,
                bitrateKbps: rate.rawValue,
                progress: { value in
                    DispatchQueue.main.async {
                        bar.doubleValue = value
                    }
                }
            )
            if let window {
                window.endSheet(alert.window)
            }
            fileURL = written
            await podcastAudioFile.loadPodcast(from: written)
            RecentFilesStore.shared.remember(written)
            if written.pathExtension.lowercased() != "mp3" {
                podcastAudioFile.errorMessage = "Wrote AAC (.m4a) instead of MP3. In-process LAME encode failed; AAC is the fallback."
            }
        } catch {
            if let window {
                window.endSheet(alert.window)
            }
            logger.error("Encode failed: \(error.localizedDescription)")
            podcastAudioFile.errorMessage = error.localizedDescription
        }
    }

    private func exportAirchecks() {
        guard let source = fileURL ?? podcastAudioFile.podcast.url else { return }
        let chapters = AircheckExporter.chaptersToExport(
            selected: Array(podcastAudioFile.selectedChapters),
            all: podcastAudioFile.podcast.chapters
        )
        guard !chapters.isEmpty else {
            podcastAudioFile.errorMessage = "No chapters to export. Select a chapter or give chapters a title."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.title = "Export Chapter Clips"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        SecurityScopedBookmarkStore.shared.rememberAndAccess(directory)

        Task { @MainActor in
            do {
                _ = try await AircheckExporter.export(from: source, chapters: chapters, to: directory)
            } catch {
                logger.error("Aircheck export failed: \(error.localizedDescription)")
                podcastAudioFile.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func openCastSnipWebsite() {
        let address = "https://castsnip.com"
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
