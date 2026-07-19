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
        store.setAnchor(anchor)
        XCTAssertEqual(
            store.load(),
            WindowFollowingPreferenceSnapshot(followingEnabled: true, anchor: anchor)
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
        XCTAssertNil(store.load().anchor)
    }
}
