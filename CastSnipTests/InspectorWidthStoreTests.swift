import Testing
import Foundation
@testable import CastSnip

struct InspectorWidthStoreTests {

    @Test func missingKeyUsesTheDefaultWidth() {
        let defaults = isolatedDefaults()
        #expect(InspectorWidthStore.load(from: defaults) == InspectorWidthStore.defaultWidth)
        #expect(InspectorWidthStore.defaultWidth == 320)
    }

    @Test func savedWidthReloadsOnANewStore() {
        let defaults = isolatedDefaults()
        InspectorWidthStore.save(360, to: defaults)
        #expect(InspectorWidthStore.load(from: defaults) == 360)
    }

    @Test func widthsBelowTheMinimumClampUp() {
        #expect(InspectorWidthStore.clamp(100) == InspectorWidthStore.minimumWidth)
        #expect(InspectorWidthStore.minimumWidth == 280)
    }

    @Test func widthsAboveTheMaximumClampDown() {
        #expect(InspectorWidthStore.clamp(900) == InspectorWidthStore.maximumWidth)
        #expect(InspectorWidthStore.maximumWidth == 460)
    }

    @Test func nonFiniteWidthsFallBackToTheDefault() {
        #expect(InspectorWidthStore.clamp(.nan) == InspectorWidthStore.defaultWidth)
        #expect(InspectorWidthStore.clamp(.infinity) == InspectorWidthStore.defaultWidth)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "CastSnip.InspectorWidthStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
