import AppKit
import SwiftUI

private struct PetRingArc: Shape {
    let center: CGPoint
    let startAngleDegrees: Double
    let sweepAngleDegrees: Double
    let radius: Double
    let progress: Double

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngleDegrees),
            endAngle: .degrees(startAngleDegrees + sweepAngleDegrees * progress),
            clockwise: false
        )
        return path
    }
}

struct PetRingView: View {
    let model: PetRingPresentationModel
    let geometry: PetRingGeometry
    let orientation: PetRingOrientation

    init(
        model: PetRingPresentationModel,
        geometry: PetRingGeometry = .standard,
        orientation: PetRingOrientation = .fixedDefault
    ) {
        self.model = model
        self.geometry = geometry
        self.orientation = orientation
    }

    var body: some View {
        ZStack {
            remainingRing(name: "Weekly", metric: model.weekly, kind: .weekly)
            if let fiveHour = model.fiveHour {
                remainingRing(name: "5 hour", metric: fiveHour, kind: .fiveHour)
            }
            if let todayTokens = model.todayTokens {
                todayRing(todayTokens)
            }
            labels
        }
        .frame(width: geometry.panelDiameter, height: geometry.panelDiameter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet Halo usage rings")
    }

    private func remainingRing(
        name: String,
        metric: RingMetricPresentation,
        kind: PetRingMetricKind
    ) -> some View {
        let value = metric.value
        return ZStack {
            track(kind: kind)
            if let value {
                progressArc(
                    kind: kind,
                    progress: value.progress,
                    level: value.semanticLevel,
                    isStale: metric.isStale
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) remaining")
        .accessibilityValue(remainingAccessibilityValue(metric))
    }

    private func todayRing(_ metric: TodayTokenPresentation) -> some View {
        let value = metric.value
        return ZStack {
            track(kind: .today)
            progressArc(
                kind: .today,
                progress: value.progress,
                level: value.semanticLevel,
                isStale: metric.isStale
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today tokens")
        .accessibilityValue(
            "\(value.tokenText), \(value.percentOfPeakText) of historical peak, "
                + "\(metric.freshnessText.lowercased()), "
                + value.semanticLevel.text.lowercased()
        )
    }

    private func track(kind: PetRingMetricKind) -> some View {
        let angles = geometry.angles(for: orientation)
        return PetRingArc(
            center: geometry.ringCenter(in: geometry.panelSize),
            startAngleDegrees: angles.startAngleDegrees,
            sweepAngleDegrees: angles.sweepAngleDegrees,
            radius: geometry.radius(for: kind),
            progress: 1
        )
        .stroke(
            Color(nsColor: .separatorColor).opacity(0.35),
            style: StrokeStyle(lineWidth: geometry.lineWidth, lineCap: .round)
        )
        .accessibilityHidden(true)
    }

    private func progressArc(
        kind: PetRingMetricKind,
        progress: Double,
        level: PetRingSemanticLevel,
        isStale: Bool
    ) -> some View {
        let angles = geometry.angles(for: orientation)
        return PetRingArc(
            center: geometry.ringCenter(in: geometry.panelSize),
            startAngleDegrees: angles.startAngleDegrees,
            sweepAngleDegrees: angles.sweepAngleDegrees,
            radius: geometry.radius(for: kind),
            progress: progress
        )
        .stroke(
            semanticColor(level).opacity(isStale ? 0.55 : 0.9),
            style: StrokeStyle(
                lineWidth: geometry.lineWidth,
                lineCap: .round,
                dash: isStale ? [5, 4] : []
            )
        )
        .accessibilityHidden(true)
    }

    private var labels: some View {
        GeometryReader { _ in
            metricLabel(prefix: "W", metric: model.weekly)
                .position(geometry.labelPosition(for: .weekly, orientation: orientation))

            if let fiveHour = model.fiveHour {
                metricLabel(prefix: "5h", metric: fiveHour)
                    .position(geometry.labelPosition(for: .fiveHour, orientation: orientation))
            }

            if let todayTokens = model.todayTokens {
                todayLabel(todayTokens)
                    .position(geometry.labelPosition(for: .today, orientation: orientation))
            }
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
        .accessibilityHidden(true)
    }

    private func metricLabel(
        prefix: String,
        metric: RingMetricPresentation
    ) -> some View {
        let valueText = metric.value?.percentText ?? "—"
        let staleText = metric.isStale ? " Stale" : ""
        return Text("\(prefix) \(valueText)\(staleText)")
            .fixedSize()
    }

    private func todayLabel(_ metric: TodayTokenPresentation) -> some View {
        let staleText = metric.isStale ? " Stale" : ""
        return Text("Today \(metric.value.tokenText)\(staleText)")
            .fixedSize()
    }

    private func remainingAccessibilityValue(_ metric: RingMetricPresentation) -> String {
        guard let value = metric.value else { return "Unavailable" }
        return "\(value.percentText), \(metric.freshnessText.lowercased()), "
            + value.semanticLevel.text.lowercased()
    }

    private func semanticColor(_ level: PetRingSemanticLevel) -> Color {
        switch level {
        case .healthy:
            Color(nsColor: .systemGreen)
        case .warning:
            Color(nsColor: .systemOrange)
        case .critical:
            Color(nsColor: .systemRed)
        }
    }
}
