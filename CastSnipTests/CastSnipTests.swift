//
//  CastSnipTests.swift
//  CastSnipTests
//
//  Created by Eric Wuehler on 1/29/26.
//

import Testing
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import CastSnip

struct ID3ParserTests {
    
    // MARK: - Time Conversion Tests
    
    @Test func testMillisecondsToTrackTime_Seconds() {
        let result = ID3Parser.toTrackTime(millis: 1000, showHours: false, showMillis: false)
        #expect(result == "0:01")
    }
    
    @Test func testMillisecondsToTrackTime_Minutes() {
        let result = ID3Parser.toTrackTime(millis: 61000, showHours: false, showMillis: false)
        #expect(result == "1:01")
    }
    
    @Test func testMillisecondsToTrackTime_Hours() {
        let result = ID3Parser.toTrackTime(millis: 3661000, showHours: true, showMillis: false)
        #expect(result == "1:01:01")
    }
    
    @Test func testMillisecondsToTrackTime_WithMilliseconds() {
        let result = ID3Parser.toTrackTime(millis: 1234, showHours: false, showMillis: true)
        #expect(result == "0:01.234")
    }
    
    @Test func testMillisecondsToTrackTime_Zero() {
        let result = ID3Parser.toTrackTime(millis: 0, showHours: false, showMillis: false)
        #expect(result == "0:00")
    }
    
    @Test func testMillisecondsToTrackTime_LargeValue() {
        // 10 hours
        let result = ID3Parser.toTrackTime(millis: 36000000, showHours: true, showMillis: false)
        #expect(result == "10:00:00")
    }
    
    // MARK: - Track to Milliseconds Tests
    
    @Test func testTrackToMillis_SecondsOnly() {
        let result = ID3Parser.trackToMillis("45")
        #expect(result == 45000)
    }
    
    @Test func testTrackToMillis_MinutesAndSeconds() {
        let result = ID3Parser.trackToMillis("1:30")
        #expect(result == 90000)
    }
    
    @Test func testTrackToMillis_HoursMinutesSeconds() {
        let result = ID3Parser.trackToMillis("1:30:45")
        #expect(result == 5445000)
    }
    
    @Test func testTrackToMillis_WithDecimalSeconds() {
        let result = ID3Parser.trackToMillis("1:30.500")
        #expect(result == 90500)
    }
    
    @Test func testTrackToMillis_Zero() {
        let result = ID3Parser.trackToMillis("0:00")
        #expect(result == 0)
    }
    
    @Test func testTrackToMillis_InvalidFormat() {
        let result = ID3Parser.trackToMillis("invalid")
        #expect(result == 0)
    }
    
    @Test func testTrackToMillis_EmptyString() {
        let result = ID3Parser.trackToMillis("")
        #expect(result == 0)
    }
    
    // MARK: - Round Trip Tests
    
    @Test func testRoundTrip_MinutesAndSeconds() {
        let original: UInt32 = 125000 // 2:05
        let timeString = ID3Parser.toTrackTime(millis: original, showHours: false, showMillis: false)
        let converted = ID3Parser.trackToMillis(timeString)
        #expect(converted == original)
    }
    
    @Test func testRoundTrip_HoursMinutesSeconds() {
        let original: UInt32 = 3723000 // 1:02:03
        let timeString = ID3Parser.toTrackTime(millis: original, showHours: true, showMillis: false)
        let converted = ID3Parser.trackToMillis(timeString)
        #expect(converted == original)
    }
    
    // MARK: - Encoding Tests
    
    @Test func testGetEncoding_ASCII() {
        let encoding = ID3Parser.getEncoding(0)
        #expect(encoding == .ASCII)
    }
    
    @Test func testGetEncoding_UCS2() {
        let encoding = ID3Parser.getEncoding(1)
        #expect(encoding == .UCS2)
    }
    
    @Test func testGetEncoding_UTF16BE() {
        let encoding = ID3Parser.getEncoding(2)
        #expect(encoding == .UTF16BE)
    }
    
    @Test func testGetEncoding_UTF8() {
        let encoding = ID3Parser.getEncoding(3)
        #expect(encoding == .UTF8)
    }
    
    @Test func testGetEncoding_Invalid() {
        let encoding = ID3Parser.getEncoding(99)
        #expect(encoding == .ASCII) // Default fallback
    }
    
    // MARK: - Data Decoding Tests
    
    @Test func testDecodeData_ASCII() {
        let data = "Hello".data(using: .ascii)!
        let result = ID3Parser.decodeData(data, .ASCII)
        #expect(result == "Hello")
    }
    
    @Test func testDecodeData_UTF8() {
        let data = "Hello 世界".data(using: .utf8)!
        let result = ID3Parser.decodeData(data, .UTF8)
        #expect(result == "Hello 世界")
    }
    
    @Test func testDecodeData_EmptyData() {
        let data = Data()
        let result = ID3Parser.decodeData(data, .ASCII)
        #expect(result == "")
    }
    
    // MARK: - Binary Data Reading Tests
    
    @Test func testGetUInt8() {
        var data = Data([0xFF])
        var offset = 0
        let result = ID3Parser.getUInt8(data, &offset)
        #expect(result == 255)
        #expect(offset == 1)
    }
    
    @Test func testGetUInt16_BigEndian() {
        var data = Data([0x01, 0x02])
        var offset = 0
        let result = ID3Parser.getUInt16(data, &offset)
        #expect(result == 258) // 0x0102 in big endian
        #expect(offset == 2)
    }
    
    @Test func testGetUInt32_BigEndian() {
        var data = Data([0x00, 0x00, 0x03, 0xE8])
        var offset = 0
        let result = ID3Parser.getUInt32(data, &offset)
        #expect(result == 1000) // 0x000003E8
        #expect(offset == 4)
    }
}

struct ChapterTests {
    
    @Test func testChapterInitialization() {
        let chapter = Chapter(title: "Test Chapter", url: "https://example.com", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        #expect(chapter.title == "Test Chapter")
        #expect(chapter.url == "https://example.com")
        #expect(chapter.startTime == 1000)
        #expect(chapter.endTime == 2000)
        #expect(chapter.podcastDuration == 10000)
    }
    
    @Test func testChapterDefaultInitialization() {
        let chapter = Chapter()
        
        #expect(chapter.title == "")
        #expect(chapter.url == "")
        #expect(chapter.startTime == 0)
        #expect(chapter.endTime == 0)
    }
    
    // MARK: - Comparison Tests
    
    @Test func testChapterComparison_LessThan() {
        let chapter1 = Chapter(startTime: 1000, endTime: 2000)
        let chapter2 = Chapter(startTime: 3000, endTime: 4000)
        
        #expect(chapter1 < chapter2)
    }
    
    @Test func testChapterComparison_GreaterThan() {
        let chapter1 = Chapter(startTime: 5000, endTime: 6000)
        let chapter2 = Chapter(startTime: 1000, endTime: 2000)
        
        #expect(chapter1 > chapter2)
    }
    
    @Test func testChapterEquality_DifferentIDs() {
        let chapter1 = Chapter(title: "Same", startTime: 1000, endTime: 2000)
        let chapter2 = Chapter(title: "Same", startTime: 1000, endTime: 2000)
        
        // Chapters are equal only if they have the same ID
        #expect(chapter1 != chapter2)
    }
    
    @Test func testChapterEquality_SameInstance() {
        let chapter = Chapter(title: "Test", startTime: 1000, endTime: 2000)
        
        #expect(chapter == chapter)
    }
    
    // MARK: - Sorting Tests
    
    @Test func testChapterSorting() {
        let chapter1 = Chapter(title: "Third", startTime: 5000, endTime: 6000)
        let chapter2 = Chapter(title: "First", startTime: 1000, endTime: 2000)
        let chapter3 = Chapter(title: "Second", startTime: 3000, endTime: 4000)
        
        let chapters = [chapter1, chapter2, chapter3]
        let sorted = chapters.sorted()
        
        #expect(sorted[0].title == "First")
        #expect(sorted[1].title == "Second")
        #expect(sorted[2].title == "Third")
    }
    
    // MARK: - Validation Tests
    
    @Test func testChapterValidation_Valid() {
        let chapter = Chapter(title: "Valid Chapter", url: "https://example.com", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.isEmpty)
        #expect(chapter.isValid())
    }
    
    @Test func testChapterValidation_InvalidTimeRange() {
        let chapter = Chapter(title: "Invalid", startTime: 2000, endTime: 1000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.contains(.invalidTimeRange))
        #expect(!chapter.isValid())
    }
    
    @Test func testChapterValidation_StartTimeExceedsDuration() {
        let chapter = Chapter(title: "Test", startTime: 15000, endTime: 16000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.contains(.startTimeExceedsDuration))
    }
    
    @Test func testChapterValidation_EndTimeExceedsDuration() {
        let chapter = Chapter(title: "Test", startTime: 1000, endTime: 15000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.contains(.endTimeExceedsDuration))
    }
    
    @Test func testChapterValidation_EmptyTitle() {
        let chapter = Chapter(title: "", url: "https://example.com", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.contains(.emptyTitle))
    }
    
    @Test func testChapterValidation_InvalidURL() {
        let chapter = Chapter(title: "Test", url: "not a valid url", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.contains(.invalidURL))
    }
    
    @Test func testChapterValidation_EmptyURL_Valid() {
        let chapter = Chapter(title: "Test", url: "", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(!errors.contains(.invalidURL)) // Empty URL is acceptable
    }
    
    @Test func testChapterValidation_ValidHTTPURL() {
        let chapter = Chapter(title: "Test", url: "http://example.com", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(!errors.contains(.invalidURL))
    }
    
    @Test func testChapterValidation_ValidHTTPSURL() {
        let chapter = Chapter(title: "Test", url: "https://example.com/path", startTime: 1000, endTime: 2000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(!errors.contains(.invalidURL))
    }
    
    @Test func testChapterValidation_MultipleErrors() {
        let chapter = Chapter(title: "", url: "bad url", startTime: 2000, endTime: 1000, podcastDuration: 10000)
        
        let errors = chapter.validate()
        #expect(errors.count >= 2)
        #expect(errors.contains(.emptyTitle))
        #expect(errors.contains(.invalidURL))
        #expect(errors.contains(.invalidTimeRange))
    }
    
    // MARK: - Update Methods Tests
    
    @Test func testUpdateTitle() {
        let chapter = Chapter(title: "Old Title", startTime: 1000, endTime: 2000)
        
        chapter.updateTitle("New Title")
        
        #expect(chapter.title == "New Title")
    }
    
    #if os(macOS)
    @Test func testUpdateImage_ValidImage() {
        let chapter = Chapter()
        let image = NSImage(systemSymbolName: "star", accessibilityDescription: "Star")
        
        chapter.updateImage(image)
        
        #expect(chapter.image != nil)
    }
    
    @Test func testUpdateImage_Nil() {
        let chapter = Chapter()
        let originalImage = NSImage(systemSymbolName: "star", accessibilityDescription: "Star")
        chapter.image = originalImage
        
        chapter.updateImage(nil)
        
        #expect(chapter.image != nil) // Should not update when nil
    }
    #endif
}

struct PodcastTests {
    
    @Test func testPodcastInitialization() {
        let podcast = Podcast()
        
        #expect(podcast.title == "")
        #expect(podcast.episode == "")
        #expect(podcast.summary == "")
        #expect(podcast.chapters.isEmpty)
        #expect(podcast.url == nil)
        #expect(podcast.logo == nil)
    }
    
    @Test func testGetFileSizeFormatted_NoSize() {
        let podcast = Podcast()
        
        let result = podcast.getFileSizeFormatted()
        #expect(result == "Unknown")
    }
    
    @Test func testGetFileSizeFormatted_SmallFile() {
        let podcast = Podcast()
        podcast.fileSizeInBytes = 1024 // 1 KB
        
        let result = podcast.getFileSizeFormatted()
        #expect(result.contains("KB") || result.contains("bytes"))
    }
    
    @Test func testGetFileSizeFormatted_MediumFile() {
        let podcast = Podcast()
        podcast.fileSizeInBytes = 5_242_880 // 5 MB
        
        let result = podcast.getFileSizeFormatted()
        #expect(result.contains("MB"))
    }
    
    @Test func testGetFileSizeFormatted_LargeFile() {
        let podcast = Podcast()
        podcast.fileSizeInBytes = 1_073_741_824 // 1 GB
        
        let result = podcast.getFileSizeFormatted()
        #expect(result.contains("GB"))
    }
    
    @Test func testGetFileSizeFormatted_ZeroBytes() {
        let podcast = Podcast()
        podcast.fileSizeInBytes = 0
        
        let result = podcast.getFileSizeFormatted()
        #expect(!result.isEmpty)
    }
    
    @Test func testPodcastWithChapters() {
        let podcast = Podcast()
        let chapter1 = Chapter(title: "Chapter 1", startTime: 0, endTime: 1000)
        let chapter2 = Chapter(title: "Chapter 2", startTime: 1000, endTime: 2000)
        
        podcast.chapters = [chapter1, chapter2]
        
        #expect(podcast.chapters.count == 2)
    }
    
    @Test func testPodcastMetadata() {
        let podcast = Podcast()
        podcast.title = "Test Podcast"
        podcast.episode = "Episode 1"
        podcast.summary = "This is a test summary"
        podcast.durationInSeconds = 3600
        podcast.durationInMillis = 3600000
        
        #expect(podcast.title == "Test Podcast")
        #expect(podcast.episode == "Episode 1")
        #expect(podcast.summary == "This is a test summary")
        #expect(podcast.durationInSeconds == 3600)
        #expect(podcast.durationInMillis == 3600000)
    }
}

struct AudioFileTests {
    
    @Test func testAudioFileInitialization() {
        let audioFile = AudioFile()
        
        #expect(!audioFile.isLoading)
        #expect(audioFile.podcast.title == "")
        #expect(audioFile.hasCoverArt() == false)
    }
    
    @Test func testHasCoverArt_NoLogo() {
        let audioFile = AudioFile()
        
        #expect(!audioFile.hasCoverArt())
    }
    
    @Test func testGetCoverArt_NoLogo() {
        let audioFile = AudioFile()
        
        let coverArt = audioFile.getCoverArt()
        #expect(coverArt == nil)
    }
    
    @Test func testGetChapterIndex_ExistingChapter() {
        let audioFile = AudioFile()
        let chapter1 = Chapter(title: "First", startTime: 0, endTime: 1000)
        let chapter2 = Chapter(title: "Second", startTime: 1000, endTime: 2000)
        
        audioFile.podcast.chapters = [chapter1, chapter2]
        
        let index = audioFile.getChapterIndex(chapter2.id)
        #expect(index == 1)
    }
    
    @Test func testGetChapterIndex_NonExistingChapter() {
        let audioFile = AudioFile()
        let chapter = Chapter(title: "First", startTime: 0, endTime: 1000)
        
        audioFile.podcast.chapters = [chapter]
        
        let randomUUID = UUID()
        let index = audioFile.getChapterIndex(randomUUID)
        #expect(index == 0) // Returns 0 when not found
    }
    
    @Test func testGetTitle() {
        let audioFile = AudioFile()
        audioFile.podcast.title = "Test Title"
        
        let binding = audioFile.getTitle()
        #expect(binding.wrappedValue == "Test Title")
    }
    
    @Test func testGetEpisode() {
        let audioFile = AudioFile()
        audioFile.podcast.episode = "Episode 42"
        
        let binding = audioFile.getEpisode()
        #expect(binding.wrappedValue == "Episode 42")
    }
    
    @Test func testGetSummary() {
        let audioFile = AudioFile()
        audioFile.podcast.summary = "This is a summary"
        
        let binding = audioFile.getSummary()
        #expect(binding.wrappedValue == "This is a summary")
    }
    
    @Test func testSetTitle() {
        let audioFile = AudioFile()
        
        var binding = audioFile.getTitle()
        binding.wrappedValue = "New Title"
        
        #expect(audioFile.podcast.title == "New Title")
    }
    
    @Test func testSetEpisode() {
        let audioFile = AudioFile()
        
        var binding = audioFile.getEpisode()
        binding.wrappedValue = "New Episode"
        
        #expect(audioFile.podcast.episode == "New Episode")
    }
    
    @Test func testSetSummary() {
        let audioFile = AudioFile()
        
        var binding = audioFile.getSummary()
        binding.wrappedValue = "New Summary"
        
        #expect(audioFile.podcast.summary == "New Summary")
    }
}
