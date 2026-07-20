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
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(received.map(\.0), [.selectionChanged])
        XCTAssertEqual(received.map(\.1), [11])

        box.enqueue(.targetInvalidated)
        box.deactivate()
        try? await Task.sleep(for: .milliseconds(100))
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

        store.setFollowingEnabled(true)
        store.setWindowAnchor(anchor)
        XCTAssertEqual(
            store.load(),
            WindowFollowingPreferenceSnapshot(
                followingEnabled: true,
                windowAnchor: anchor,
                petAnchor: nil
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
    func testPetAnchorUsesSeparatePreferenceKeyAndRejectsInvalidVersion() throws {
        let suiteName = "io.github.jianshicodes.PetHaloTests.PetFollowingPreferences"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWindowFollowingPreferences(defaults: defaults)
        let anchor = PetRelativeAnchor(
            version: 1,
            normalizedPetPoint: UnitPointValue(x: 0.75, y: 0.25),
            pointOffset: PointOffsetValue(width: 30, height: -10)
        )

        store.setPetAnchor(anchor)
        XCTAssertEqual(store.load().petAnchor, anchor)
        XCTAssertNil(store.load().windowAnchor)

        let invalid = PetRelativeAnchor(
            version: 0,
            normalizedPetPoint: UnitPointValue(x: 0.5, y: 0.5),
            pointOffset: PointOffsetValue(width: 0, height: 0)
        )
        defaults.set(
            try JSONEncoder().encode(invalid),
            forKey: "io.github.jianshicodes.PetHalo.petFollowing.anchor.v1"
        )
        XCTAssertNil(store.load().petAnchor)
    }
}
