//
//  AudioModel.swift
//  CastSnip
//
//  Created by ewuehler on 4/21/24.
//

import SwiftUI
import AVFoundation
import OSLog

@Observable
class AudioFile: Identifiable {
 
    let id3String = ["TALB", "TPE1", "TIT2", "COMM", "USLT", "TLEN", "TYER", "TENC"]
    let id3Data = ["CTOC", "CHAP", "APIC"]
    
    var podcast = Podcast()
    var isLoading = false
    var errorMessage: String?
    var hasUnsavedChanges = false
    private let logger = Logger(subsystem: "com.castsnip", category: "AudioFile")
    
    @MainActor
    func loadPodcast(from url: URL) async {
        isLoading = true
        errorMessage = nil
        podcast = await loadingPodcast(from: url)
        
        // Check for loading failures
        if podcast.asset == nil {
            errorMessage = "Failed to load audio file. The file may be corrupted or in an unsupported format."
        } else if podcast.durationInSeconds == 0 {
            errorMessage = "Warning: Could not determine audio duration."
        }
        
        isLoading = false
    }
    
    func markAsModified() {
        hasUnsavedChanges = true
    }
    
    func markAsSaved() {
        hasUnsavedChanges = false
    }
    
    func hasCoverArt() -> Bool {
        return podcast.logo != nil
    }
    
    func getCoverArt() -> Image? {
        if (hasCoverArt()) {
            #if os(iOS)
            return Image(uiImage: podcast.logo!)
            #else
            return Image(nsImage: podcast.logo!)
            #endif
        } else {
            return nil
        }
    }
    
    func getTitle() -> Binding<String> {
        return Binding(get: { self.podcast.title }, set: { self.podcast.title = $0 })
    }
    
    func getEpisode() -> Binding<String> {
        return Binding(get: { self.podcast.episode }, set: { self.podcast.episode = $0 })
    }
    
    func getSummary() -> Binding<String> {
        return Binding(get: { self.podcast.summary }, set: { self.podcast.summary = $0 })
    }
    
    func getChapterIndex(_ id: UUID) -> Int {
        var chapterIndex: Int {
            podcast.chapters.firstIndex(where: {$0.id == id}) ?? 0
        }
        return chapterIndex
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
        var pa = Podcast()
        pa.url = url
        pa.file = getFile(from: url)
        
        // Get file size
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
            // Convert the duration to seconds
            pa.durationInSeconds = CGFloat(dur?.value ?? 1)/CGFloat(dur?.timescale ?? 1)
            pa.durationInMillis = UInt32((pa.durationInSeconds ?? 0)*1000)
        } catch {
            logger.error("Failed to load duration: \(error.localizedDescription)")
            pa.durationInSeconds = 0
            pa.durationInMillis = 0
        }
        
        guard let asset = pa.asset else {
            logger.error("Asset is nil, cannot load metadata")
            return pa
        }
        
        do {
            for item in try await asset.loadMetadata(for: .id3Metadata) {
                let key = item.key?.description ?? "unknown"
                if id3String.contains(key) {
                    do {
                        let value = try await item.load(.stringValue)
                        logger.debug("\(key) = \(value ?? "nil")")
                        if ("TALB" == key) || ("TPE1" == key) {
                            pa.title = value ?? ""
                        } else if ("TIT2" == key) {
                            pa.episode = value ?? ""
                        } else if ("COMM" == key) || ("USLT" == key) {
                            pa.summary = value ?? ""
                        } else if ("TLEN" == key) {
                            if let tlen = UInt32(value ?? "0") {
                                if tlen > 0 && pa.durationInMillis == 0 {
                                    pa.durationInMillis = tlen
                                }
                            }
                        }
                    } catch {
                        logger.error("Failed to load string value for key \(key): \(error.localizedDescription)")
                    }
                } else if id3Data.contains(key) {
                    do {
                        if let value = try await item.load(.dataValue) {
                            if ("CHAP" == key) {
                                let c = Chapter(data: value, podcastDuration: pa.durationInMillis ?? 0)
                                pa.chapters.append(c)
                            } else if ("CTOC" == key) {
                                // Table of contents - future implementation
                                logger.debug("CTOC tag found")
                            } else if ("APIC" == key) {
                                #if os(iOS)
                                pa.logo = UIImage(data: value)
                                #else
                                pa.logo = NSImage(data: value)
                                #endif
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
        
//        do {
//            print("itunes metadata")
//            for item in try await pa.asset!.loadMetadata(for: .iTunesMetadata) {
//                let key = item.key?.description ?? "unknown"
//                print("key: \(key)")
//
//            }
//        } catch {
//            print("error itunes metadata: \(error)")
//        }
        
        return pa
    }
    
}


