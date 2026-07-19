import XCTest
@testable import PetHalo

final class HaloAccessibilityTests: XCTestCase {
    private let quota = QuotaPresentation(
        remainingPercent: 81,
        displayedPercent: 81,
        resetText: "Resets in 2 hr",
        resetAccessibilityValue: "Jul 20, 2026 at 8:00 PM"
    )

    func testQuotaAccessibilityIncludesIdentityPercentageFreshnessAndReset() {
        XCTAssertEqual(
            HaloAccessibility.metricValue(name: "Weekly quota", state: .current(quota)),
            "Weekly quota, 81% remaining, current, reset Jul 20, 2026 at 8:00 PM"
        )
        XCTAssertTrue(
            HaloAccessibility.metricValue(name: "Weekly quota", state: .stale(quota))
                .contains("stale")
        )
        XCTAssertEqual(
            HaloAccessibility.metricValue(name: "Weekly quota", state: .unavailable),
            "Weekly quota, unavailable"
        )
    }

    func testAccountUsageAccessibilityIsExplicitAndContainsNoRawFailure() {
        let usage = AccountUsagePresentation(
            summaryRows: [AccountUsageRowPresentation(label: "Peak daily tokens", value: "2,000")],
            dailyRows: []
        )

        let value = HaloAccessibility.accountUsageValue(.stale(usage))
        XCTAssertTrue(value.contains("Account Usage, stale"))
        XCTAssertTrue(value.contains("Peak daily tokens, 2,000"))
        XCTAssertFalse(value.contains("accountUsageUnavailable"))
        XCTAssertEqual(
            HaloAccessibility.accountUsageValue(.unavailable),
            "Account Usage, unavailable"
        )
    }
}
