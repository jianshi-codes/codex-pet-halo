import CoreGraphics
import Foundation
import XCTest
@testable import PetHalo

final class WindowFollowingSystemTests: XCTestCase {
    @MainActor
    func testAccessibilityCallbackBurstIsBoundedAndInvalidationWins() async {
        var received: [CodexWindowObservationEvent] = []
        let box = AXCallbackBox(generation: 7) { event, generation in
            XCTAssertEqual(generation, 7)
            received.append(event)
        }

        for _ in 0 ..< 100 {
            box.enqueue(.geometryChanged)
        }
        box.enqueue(.selectionChanged)
        box.enqueue(.targetInvalidated)
        try? await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(received, [.targetInvalidated])
        box.deactivate()
        box.enqueue(.geometryChanged)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(received, [.targetInvalidated])
    }

    @MainActor
    func testPetCallbackBurstCoalescesAndStopsWithoutLateDelivery() async {
        var received: [(PetTargetObservationEvent, Int)] = []
        let box = PetAXCallbackBox(generation: 11) { event, generation in
            received.append((event, generation))
        }

        for _ in 0 ..< 100 {
            box.enqueue(.geometryChanged)
        }
        box.enqueue(.selectionChanged)
        for _ in 0 ..< 10 where received.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(received.map(\.0), [.selectionChanged])
        XCTAssertEqual(received.map(\.1), [11])

        box.enqueue(.targetInvalidated)
        box.deactivate()
        for _ in 0 ..< 10 { await Task.yield() }
        XCTAssertEqual(received.map(\.0), [.selectionChanged])
    }

    @MainActor
    func testPreferencesRoundTripOnlyVersionedPlacementAndRejectOldVersion() throws {
        let suiteName = "io.github.jianshicodes.PetHaloTests.WindowFollowingPreferences"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWindowFollowingPreferences(defaults: defaults)
        let anchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.75, y: 0.25),
            pointOffset: PointOffsetValue(width: 48, height: -12)
        )

        let visualOffset = PetVisualCenterOffset(horizontal: -12, vertical: 36)
        defaults.set(
            try JSONEncoder().encode(visualOffset),
            forKey: "io.github.jianshicodes.PetHalo.petRing.visualCenterOffset.v1"
        )
        XCTAssertEqual(store.load().petVisualCenterOffset, .zero)

        store.setFollowingEnabled(true)
        store.setWindowAnchor(anchor)
        store.setPetVisualCenterOffset(visualOffset)
        XCTAssertEqual(
            store.load(),
            WindowFollowingPreferenceSnapshot(
                followingEnabled: true,
                windowAnchor: anchor,
                petVisualCenterOffset: visualOffset
            )
        )

        let oldAnchor = HaloWindowAnchor(
            version: 0,
            normalizedWindowPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        defaults.set(
            try JSONEncoder().encode(oldAnchor),
            forKey: "io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1"
        )
        XCTAssertNil(store.load().windowAnchor)
    }

    @MainActor
    func testLegacyPetAnchorMigrationRemovesOnlyPetKey() throws {
        let suiteName = "io.github.jianshicodes.PetHaloTests.PetFollowingPreferences"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWindowFollowingPreferences(defaults: defaults)
        let windowAnchor = HaloWindowAnchor(
            version: 1,
            normalizedWindowPoint: UnitPointValue(x: 0.75, y: 0.25),
            pointOffset: PointOffsetValue(width: 30, height: -10)
        )
        let legacyKey = "io.github.jianshicodes.PetHalo.petFollowing.anchor.v1"

        store.setWindowAnchor(windowAnchor)
        let visualOffset = PetVisualCenterOffset(horizontal: 4, vertical: 28)
        store.setPetVisualCenterOffset(visualOffset)
        defaults.set(Data("legacy-anchor".utf8), forKey: legacyKey)
        XCTAssertNotNil(defaults.object(forKey: legacyKey))

        store.removeLegacyPetAnchor()
        store.removeLegacyPetAnchor()

        XCTAssertNil(defaults.object(forKey: legacyKey))
        XCTAssertEqual(store.load().windowAnchor, windowAnchor)
        XCTAssertEqual(store.load().petVisualCenterOffset, visualOffset)
    }
}
