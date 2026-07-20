import AppKit
import SwiftUI
import XCTest
@testable import PetHalo

final class PetRingPolishTests: XCTestCase {
    func testAppearancePoliciesCoverLiveSystemVariants() {
        let light = PetRingAppearancePolicy.resolve(
            appearance: .light,
            increaseContrast: false,
            reduceTransparency: false
        )
        let dark = PetRingAppearancePolicy.resolve(
            appearance: .dark,
            increaseContrast: false,
            reduceTransparency: false
        )
        let increased = PetRingAppearancePolicy.resolve(
            appearance: .light,
            increaseContrast: true,
            reduceTransparency: false
        )
        let opaque = PetRingAppearancePolicy.resolve(
            appearance: .dark,
            increaseContrast: false,
            reduceTransparency: true
        )

        XCTAssertNotEqual(light, dark)
        XCTAssertGreaterThan(increased.capsuleBorderOpacity, light.capsuleBorderOpacity)
        XCTAssertGreaterThan(increased.trackOpacity, light.trackOpacity)
        XCTAssertEqual(opaque.capsuleBackgroundOpacity, 1)
        XCTAssertEqual(opaque.shadowOpacity, 0)
    }

    func testIdentityDotsStayFixedAndTextVariantsMeetPracticalContrast() {
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        XCTAssertEqual(
            metrics.map { PetRingPresentationPolicy.identityColor(for: $0).hex },
            ["#5865F2", "#00B8D9", "#A855F7"]
        )
        let lightBackground = PetRingIdentityColor(red: 0xFF, green: 0xFF, blue: 0xFF)
        let darkBackground = PetRingIdentityColor(red: 0x1C, green: 0x1C, blue: 0x1E)
        for metric in metrics {
            let lightText = PetRingPresentationPolicy.identityTextColor(
                for: metric,
                appearance: .light
            )
            let darkText = PetRingPresentationPolicy.identityTextColor(
                for: metric,
                appearance: .dark
            )
            XCTAssertGreaterThanOrEqual(lightText.contrastRatio(against: lightBackground), 4.5)
            XCTAssertGreaterThanOrEqual(darkText.contrastRatio(against: darkBackground), 4.5)
        }
        XCTAssertNotEqual(
            PetRingPresentationPolicy.identityTextColor(for: .fiveHour, appearance: .light),
            PetRingPresentationPolicy.identityColor(for: .fiveHour)
        )
    }

    func testSafeSideUsesVisibleFrameAtLeftAndRightEdgesWithoutMovingCenter() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1_440, height: 860)
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        let leftEdgePanel = panelFrame(centerX: 32)
        let rightEdgePanel = panelFrame(centerX: 1_408)

        let leftEdgeSide = PetRingLabelPlacementPolicy.side(
            panelFrame: leftEdgePanel,
            visibleFrame: visibleFrame,
            visibleMetrics: metrics,
            preferredSide: .left,
            currentSide: nil
        )
        let rightEdgeSide = PetRingLabelPlacementPolicy.side(
            panelFrame: rightEdgePanel,
            visibleFrame: visibleFrame,
            visibleMetrics: metrics,
            preferredSide: .right,
            currentSide: nil
        )

        XCTAssertEqual(leftEdgeSide, .right)
        XCTAssertEqual(rightEdgeSide, .left)
        XCTAssertTrue(visibleFrame.contains(labelFrame(side: leftEdgeSide, panel: leftEdgePanel)))
        XCTAssertTrue(visibleFrame.contains(labelFrame(side: rightEdgeSide, panel: rightEdgePanel)))
        XCTAssertEqual(leftEdgePanel.midX, 32)
        XCTAssertEqual(rightEdgePanel.midX, 1_408)
    }

    func testNegativeCoordinateDisplayAndDialogOpeningAreIndependent() {
        let visibleFrame = CGRect(x: -1_440, y: 24, width: 1_440, height: 860)
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        let panel = panelFrame(centerX: -1_408)
        let orientation = PetRingOrientation.openingBottom
        let side = PetRingLabelPlacementPolicy.side(
            panelFrame: panel,
            visibleFrame: visibleFrame,
            visibleMetrics: metrics,
            preferredSide: orientation.preferredLabelSide,
            currentSide: nil
        )

        XCTAssertEqual(orientation, .openingBottom)
        XCTAssertEqual(side, .right)
        XCTAssertEqual(PetRingGeometry.standard.angles(for: orientation).startAngleDegrees, 140)
        XCTAssertTrue(visibleFrame.contains(labelFrame(side: side, panel: panel)))
        XCTAssertEqual(panel.midX, -1_408)
    }

    func testSafeSideHysteresisNeverPermitsClipping() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let metrics: [PetRingMetricKind] = [.weekly, .fiveHour, .today]
        let nearBoundary = panelFrame(centerX: 1_218)
        let settled = panelFrame(centerX: 1_210)

        XCTAssertEqual(PetRingLabelPlacementPolicy.side(
            panelFrame: nearBoundary,
            visibleFrame: visibleFrame,
            visibleMetrics: metrics,
            preferredSide: .right,
            currentSide: .left
        ), .left)
        XCTAssertEqual(PetRingLabelPlacementPolicy.side(
            panelFrame: settled,
            visibleFrame: visibleFrame,
            visibleMetrics: metrics,
            preferredSide: .right,
            currentSide: .left
        ), .right)
        XCTAssertTrue(visibleFrame.contains(labelFrame(side: .left, panel: nearBoundary)))
        XCTAssertTrue(visibleFrame.contains(labelFrame(side: .right, panel: settled)))
    }

    @MainActor
    func testOptionalMetricsAndLargestValuesLayOutAtLargeTextSize() {
        let geometry = PetRingGeometry.standard
        let combinations: [[PetRingMetricKind]] = [
            [.weekly],
            [.weekly, .fiveHour],
            [.weekly, .today],
            [.weekly, .fiveHour, .today],
        ]
        for metrics in combinations {
            let frames = metrics.map {
                geometry.labelFrame(for: $0, side: .right, visibleMetrics: metrics)
            }
            XCTAssertTrue(frames.allSatisfy { CGRect(origin: .zero, size: geometry.panelSize).contains($0) })
            for first in frames.indices {
                for second in frames.indices where first < second {
                    XCTAssertFalse(frames[first].intersects(frames[second]))
                }
            }
        }

        let maximumModel = PetRingPresentationModel(
            weekly: .current(metric(remaining: 100)),
            fiveHour: .current(metric(remaining: 100)),
            todayTokens: .current(TodayTokenValue(
                tokenCount: UInt64.max,
                tokenText: "18,446,744,073,709,551,615 tokens",
                compactTokenText: "18.4B",
                peakDailyTokenCount: UInt64.max,
                peakTokenText: "18,446,744,073,709,551,615 tokens",
                consumptionRatio: 1,
                semanticLevel: .critical
            )),
            accessibilityValue: "Maximum values"
        )
        let hosting = NSHostingView(rootView: PetRingView(model: maximumModel)
            .environment(\.dynamicTypeSize, .accessibility5))
        hosting.frame = CGRect(origin: .zero, size: geometry.panelSize)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(hosting.fittingSize, geometry.panelSize)
    }

    private func panelFrame(centerX: CGFloat) -> CGRect {
        let size = PetRingGeometry.standard.panelSize
        return CGRect(
            x: centerX - size.width / 2,
            y: 320,
            width: size.width,
            height: size.height
        )
    }

    private func labelFrame(side: PetRingLabelSide, panel: CGRect) -> CGRect {
        PetRingLabelPlacementPolicy.globalLabelFrame(
            side: side,
            panelFrame: panel,
            visibleMetrics: [.weekly, .fiveHour, .today]
        )
    }

    private func metric(remaining: Double) -> RingMetricValue {
        RingMetricValue(
            remainingPercent: remaining,
            displayedPercent: Int(remaining),
            semanticLevel: .healthy
        )
    }
}
