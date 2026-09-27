//
//  AudioFile.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation
import AppKit
import OSLog

@Observable
class AudioFile: Identifiable {
 
    let id3String = ["TALB", "TPE1", "TIT2", "COMM", "USLT", "TLEN", "TYER", "TENC"]
    let id3Data = ["CTOC", "CHAP", "APIC"]
    
    var podcast = Podcast()
    var isLoading = false
    var errorMessage: String?
    var hasUnsavedChanges = false
    var selectedChapters: Set<Chapter> = []
    var selectedChapter: Chapter? {
        get { selectedChapters.min() }
        set {
            if let newValue {
                selectedChapters = [newValue]
            } else {
                selectedChapters = []
            }
        }
    }
    private let logger = Logger(subsystem: "com.castsnip", category: "AudioFile")
    
    @MainActor
    func loadPodcast(from url: URL) async {
        isLoading = true
        errorMessage = nil
        podcast = await loadingPodcast(from: url)
        
        if podcast.asset == nil {
            errorMessage = "Failed to load audio file. The file may be corrupted or in an unsupported format."
        } else if podcast.durationInSeconds == 0, errorMessage == nil {
            errorMessage = "Warning: Could not determine audio duration."
        }

        ShowAutofillStore.shared.applyToPodcastIfEmpty(podcast, filename: url.path)
        
        isLoading = false
        hasUnsavedChanges = false
    }

    func save(to destination: URL, includeTags: Bool = true) throws {
        guard let source = podcast.url else {
            throw ID3WriterError.unreadableSource
        }
        try ID3Writer.write(podcast: podcast, from: source, to: destination, includeTags: includeTags)
        podcast.url = destination
        if let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
           let size = attributes[.size] as? UInt64 {
            podcast.fileSizeInBytes = size
        }
        if !podcast.title.isEmpty,
           !destination.path.contains("/Contents/Resources/"),
           !SampleEpisode.isSample(destination),
           let parsed = ShowAutofillStore.parse(destination.lastPathComponent) {
            ShowAutofillStore.shared.rememberShow(
                prefix: parsed.prefix,
                title: podcast.title,
                artwork: podcast.logo
            )
        }
        markAsSaved()
    }

    func canSaveInPlace(to url: URL?) -> Bool {
        guard let url else { return false }
        if url.path.contains("/Contents/Resources/") {
            return false
        }
        if let resourceURL = Bundle.main.resourceURL,
           url.standardizedFileURL.path.hasPrefix(resourceURL.standardizedFileURL.path) {
            return false
        }
        return true
    }
    
    func markAsModified() {
        hasUnsavedChanges = true
    }
    
    func markAsSaved() {
        hasUnsavedChanges = false
    }

    func closeDocument() {
        podcast = Podcast()
        selectedChapter = nil
        hasUnsavedChanges = false
        errorMessage = nil
        isLoading = false
    }

    func silenceRanges(
        thresholdDb: Double? = nil,
        durationSeconds: TimeInterval? = nil,
        settings: SilenceSettingsStore = .shared
    ) -> [SilenceDetector.Range] {
        guard let file = podcast.file else { return [] }
        do {
            return try SilenceDetector.detect(
                in: file,
                thresholdDb: thresholdDb ?? settings.thresholdDb,
                durationSeconds: durationSeconds ?? settings.durationSeconds
            )
        } catch {
            logger.error("Silence detection failed: \(error.localizedDescription)")
            return []
        }
    }

    func selectNeighbor(going direction: ChapterTimeline.NeighborDirection) {
        selectedChapter = ChapterTimeline.neighbor(
            of: selectedChapter,
            in: podcast.chapters,
            going: direction
        )
    }
    
    func hasCoverArt() -> Bool {
        return podcast.logo != nil
    }
    
    func getCoverArt() -> Image? {
        if let logo = podcast.logo {
            return Image(nsImage: logo)
        }
        return nil
    }
    
    func getTitle() -> Binding<String> {
        dirtyBinding(\.title)
    }
    
    func getEpisode() -> Binding<String> {
        dirtyBinding(\.episode)
    }
    
    func getSummary() -> Binding<String> {
        dirtyBinding(\.summary)
    }
    
    func getChapterIndex(_ id: UUID) -> Int {
        podcast.chapters.firstIndex(where: { $0.id == id }) ?? 0
    }

    private func dirtyBinding(_ keyPath: ReferenceWritableKeyPath<Podcast, String>) -> Binding<String> {
        Binding(
            get: { self.podcast[keyPath: keyPath] },
            set: { newValue in
                if self.podcast[keyPath: keyPath] != newValue {
                    self.podcast[keyPath: keyPath] = newValue
                    self.markAsModified()
                }
            }
        )
    }
    
    private func getFile(from url: URL) -> AVAudioFile? {
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            logger.error("Failed to read audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadingPodcast(from url: URL) async -> Podcast {
        let pa = Podcast()
        pa.url = url
        pa.file = getFile(from: url)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? UInt64 {
                pa.fileSizeInBytes = fileSize
            }
        } catch {
            logger.error("Failed to get file size: \(error.localizedDescription)")
        }
        
        pa.asset = AVURLAsset(url: url, options: nil)
        do {
            let dur = try await pa.asset?.load(.duration)
            let timescale = dur?.timescale ?? 1
            if timescale == 0 {
                pa.durationInSeconds = 0
                pa.durationInMillis = 0
            } else {
                pa.durationInSeconds = CGFloat(dur?.value ?? 1) / CGFloat(timescale)
                pa.durationInMillis = UInt32((pa.durationInSeconds ?? 0) * 1000)
            }
        } catch {
            logger.error("Failed to load duration: \(error.localizedDescription)")
            pa.durationInSeconds = 0
            pa.durationInMillis = 0
        }
        
        guard let asset = pa.asset else {
            logger.error("Asset is nil, cannot load metadata")
            return pa
        }
        
        var tocChildIDs: [String]?
        do {
            for item in try await asset.loadMetadata(for: .id3Metadata) {
                let key = item.key?.description ?? "unknown"
                if id3String.contains(key) {
                    do {
                        let value = try await item.load(.stringValue)
                        logger.debug("\(key) = \(value ?? "nil")")
                        if let value {
                            ID3MetadataMapping.applyString(key: key, value: value, to: pa)
                        }
                    } catch {
                        logger.error("Failed to load string value for key \(key): \(error.localizedDescription)")
                    }
                } else if id3Data.contains(key) {
                    do {
                        if let value = try await item.load(.dataValue) {
                            if key == "CHAP" {
                                let c = Chapter(data: value, podcastDuration: pa.durationInMillis ?? 0)
                                pa.chapters.append(c)
                            } else if key == "CTOC" {
                                tocChildIDs = ID3Parser.ctocChildIDs(from: value)
                            } else if key == "APIC" {
                                pa.logo = NSImage(data: value)
                            }
                        }
                    } catch {
                        logger.error("Failed to load data value for key \(key): \(error.localizedDescription)")
                    }
                } else {
                    do {
                        let value = try await item.load(.dataValue)
                        logger.debug("Unknown key: \(key), data length: \(value?.count ?? 0)")
                    } catch {
                        logger.error("Failed to load unknown key \(key): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("Error loading id3 metadata: \(error.localizedDescription)")
        }

        ChapterVisibility.apply(tocChildIDs: tocChildIDs, to: pa.chapters)

        if pa.chapters.isEmpty {
            do {
                pa.chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: pa.durationInMillis ?? 0)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        return pa
    }
}
