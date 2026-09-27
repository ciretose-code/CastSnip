import Testing
import Foundation
@testable import CastSnip

struct EditorSplitStoreTests {

    @Test func missingKeyUsesTheDefaultFraction() {
        let defaults = isolatedDefaults()
        #expect(EditorSplitStore.load(from: defaults) == EditorSplitStore.defaultFraction)
        #expect(EditorSplitStore.defaultFraction == 0.5)
    }

    @Test func savedFractionReloadsOnANewStore() {
        let defaults = isolatedDefaults()
        EditorSplitStore.save(0.35, to: defaults)
        #expect(EditorSplitStore.load(from: defaults) == 0.35)
    }

    @Test func fractionsBelowTheMinimumClampUp() {
        #expect(EditorSplitStore.clamp(0.01) == EditorSplitStore.minimumFraction)
        #expect(EditorSplitStore.clamp(-2) == EditorSplitStore.minimumFraction)
        #expect(EditorSplitStore.minimumFraction == 0.2)
    }

    @Test func fractionsAboveTheMaximumClampDown() {
        #expect(EditorSplitStore.clamp(0.99) == EditorSplitStore.maximumFraction)
        #expect(EditorSplitStore.clamp(4) == EditorSplitStore.maximumFraction)
        #expect(EditorSplitStore.maximumFraction == 0.8)
    }

    @Test func nonFiniteFractionsFallBackToTheDefault() {
        #expect(EditorSplitStore.clamp(.nan) == EditorSplitStore.defaultFraction)
        #expect(EditorSplitStore.clamp(.infinity) == EditorSplitStore.defaultFraction)
    }

    @Test func savePersistsTheClampedValue() {
        let defaults = isolatedDefaults()
        EditorSplitStore.save(1.5, to: defaults)
        #expect(EditorSplitStore.load(from: defaults) == EditorSplitStore.maximumFraction)
    }

    @Test func fractionFromPaneHeightsUsesChapterShare() {
        #expect(EditorSplitStore.fraction(chapterHeight: 120, totalHeight: 400) == 0.3)
        #expect(EditorSplitStore.fraction(chapterHeight: 10, totalHeight: 400) == EditorSplitStore.minimumFraction)
        #expect(EditorSplitStore.fraction(chapterHeight: 100, totalHeight: 0) == EditorSplitStore.defaultFraction)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "CastSnip.EditorSplitStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
