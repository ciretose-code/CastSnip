//
//  ID3MetadataMappingEdgeTests.swift
//  CastSnipTests
//

import Testing
import Foundation
@testable import CastSnip

struct ID3MetadataMappingEdgeTests {

    @Test func usltDoesNotOverwriteNonEmptyCOMMSummary() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "COMM", value: "Show notes", to: podcast)
        ID3MetadataMapping.applyString(key: "USLT", value: "Lyrics", to: podcast)
        #expect(podcast.summary == "Show notes")
    }

    @Test func usltFillsSummaryWhenEmpty() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "USLT", value: "Lyrics", to: podcast)
        #expect(podcast.summary == "Lyrics")
    }

    @Test func tlenIgnoredWhenDurationAlreadySet() {
        let podcast = Podcast()
        podcast.durationInMillis = 5_000
        ID3MetadataMapping.applyString(key: "TLEN", value: "12000", to: podcast)
        #expect(podcast.durationInMillis == 5_000)
    }

    @Test func tlenAppliedWhenDurationIsNil() {
        let podcast = Podcast()
        #expect(podcast.durationInMillis == nil)
        ID3MetadataMapping.applyString(key: "TLEN", value: "12000", to: podcast)
        #expect(podcast.durationInMillis == 12_000)
    }

    @Test func tlenAppliedWhenDurationIsZero() {
        let podcast = Podcast()
        podcast.durationInMillis = 0
        ID3MetadataMapping.applyString(key: "TLEN", value: "12000", to: podcast)
        #expect(podcast.durationInMillis == 12_000)
    }

    @Test func tlenIgnoredWhenValueIsZero() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TLEN", value: "0", to: podcast)
        #expect(podcast.durationInMillis == nil)
    }

    @Test func tlenIgnoredWhenValueIsNonNumeric() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TLEN", value: "abc", to: podcast)
        #expect(podcast.durationInMillis == nil)
    }

    @Test func tyerSetsYear() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TYER", value: "2024", to: podcast)
        #expect(podcast.year == "2024")
    }

    @Test func tdrcSetsYearFromLeadingDigits() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TDRC", value: "2026-03-15", to: podcast)
        #expect(podcast.year == "2026")
    }

    @Test func unknownKeyIsNoOp() {
        let podcast = Podcast()
        podcast.title = "Show"
        podcast.episode = "Ep"
        podcast.artist = "Artist"
        podcast.summary = "Notes"
        podcast.year = "2020"
        podcast.durationInMillis = 1_000

        ID3MetadataMapping.applyString(key: "XXXX", value: "ignored", to: podcast)

        #expect(podcast.title == "Show")
        #expect(podcast.episode == "Ep")
        #expect(podcast.artist == "Artist")
        #expect(podcast.summary == "Notes")
        #expect(podcast.year == "2020")
        #expect(podcast.durationInMillis == 1_000)
    }

    /// Empty TALB/TIT2 values still overwrite. Mapping does not skip empty strings.
    @Test func emptyTALBStillAssignsTitle() {
        let podcast = Podcast()
        podcast.title = "Existing"
        ID3MetadataMapping.applyString(key: "TALB", value: "", to: podcast)
        #expect(podcast.title == "")
    }

    /// Empty TALB/TIT2 values still overwrite. Mapping does not skip empty strings.
    @Test func emptyTIT2StillAssignsEpisode() {
        let podcast = Podcast()
        podcast.episode = "Existing"
        ID3MetadataMapping.applyString(key: "TIT2", value: "", to: podcast)
        #expect(podcast.episode == "")
    }
}
