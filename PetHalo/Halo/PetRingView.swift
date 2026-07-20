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
    let labelSide: PetRingLabelSide
    let isCalibrating: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        model: PetRingPresentationModel,
        geometry: PetRingGeometry = .standard,
        orientation: PetRingOrientation = .fixedDefault,
        labelSide: PetRingLabelSide = .right,
        isCalibrating: Bool = false
    ) {
        self.model = model
        self.geometry = geometry
        self.orientation = orientation
        self.labelSide = labelSide
        self.isCalibrating = isCalibrating
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
            if isCalibrating {
                calibrationOverlay
            }
        }
        .frame(width: geometry.panelSize.width, height: geometry.panelSize.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet Halo usage rings")
    }

    private var calibrationOverlay: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(nsColor: .controlAccentColor).opacity(0.8),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .frame(
                    width: geometry.transparentCenterDiameter,
                    height: geometry.transparentCenterDiameter
                )
            Rectangle()
                .fill(Color(nsColor: .controlAccentColor).opacity(0.8))
                .frame(width: 24, height: 1)
            Rectangle()
                .fill(Color(nsColor: .controlAccentColor).opacity(0.8))
                .frame(width: 1, height: 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adjust Ring Center calibration active")
        .allowsHitTesting(false)
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
            Color(nsColor: .separatorColor).opacity(appearancePolicy.trackOpacity),
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
            connector(for: .weekly, isStale: model.weekly.isStale)

            metricLabel(prefix: "W", metric: model.weekly, kind: .weekly)
                .frame(
                    width: geometry.labelSize(for: .weekly).width,
                    height: geometry.labelSize(for: .weekly).height
                )
                .position(labelPosition(for: .weekly))

            if let fiveHour = model.fiveHour {
                connector(for: .fiveHour, isStale: fiveHour.isStale)

                metricLabel(prefix: "5h", metric: fiveHour, kind: .fiveHour)
                    .frame(
                        width: geometry.labelSize(for: .fiveHour).width,
                        height: geometry.labelSize(for: .fiveHour).height
                    )
                    .position(labelPosition(for: .fiveHour))
            }

            if let todayTokens = model.todayTokens {
                connector(for: .today, isStale: todayTokens.isStale)

                todayLabel(todayTokens, kind: .today)
                    .frame(
                        width: geometry.labelSize(for: .today).width,
                        height: geometry.labelSize(for: .today).height
                    )
                    .position(labelPosition(for: .today))
            }
        }
        .accessibilityHidden(true)
    }

    private func connector(
        for kind: PetRingMetricKind,
        isStale: Bool
    ) -> some View {
        let segment = geometry.connectorSegment(
            for: kind,
            side: labelSide,
            visibleMetrics: visibleMetrics
        )
        return Path { path in
            path.move(to: segment.ringPoint)
            path.addLine(to: segment.capsulePoint)
        }
        .stroke(
            Color(nsColor: .separatorColor).opacity(
                isStale ? appearancePolicy.connectorOpacity * 0.7
                    : appearancePolicy.connectorOpacity
            ),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 3])
        )
    }

    private func metricLabel(
        prefix: String,
        metric: RingMetricPresentation,
        kind: PetRingMetricKind
    ) -> some View {
        let valueText = metric.value?.percentText ?? "—"
        return capsuleLabel(
            key: prefix,
            value: valueText,
            kind: kind,
            isStale: metric.isStale,
            isUnavailable: metric.value == nil,
            semanticLevel: metric.value?.semanticLevel
        )
    }

    private func todayLabel(
        _ metric: TodayTokenPresentation,
        kind: PetRingMetricKind
    ) -> some View {
        capsuleLabel(
            key: "T",
            value: "\(metric.value.compactTokenText) · \(metric.value.percentOfPeakText)",
            kind: kind,
            isStale: metric.isStale,
            isUnavailable: false,
            semanticLevel: metric.value.semanticLevel
        )
    }

    private func capsuleLabel(
        key: String,
        value: String,
        kind: PetRingMetricKind,
        isStale: Bool,
        isUnavailable: Bool,
        semanticLevel: PetRingSemanticLevel?
    ) -> some View {
        let dotColor = identityColor(for: kind)
        let textColor = identityTextColor(for: kind)
        return HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(key)
                .foregroundStyle(textColor)
            Text(isUnavailable ? "N/A" : value)
                .foregroundStyle(Color(nsColor: .labelColor))
            if let statusSymbol = statusSymbol(
                isStale: isStale,
                isUnavailable: isUnavailable,
                semanticLevel: semanticLevel
            ) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(nsColor: .labelColor))
            }
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(kind == .today ? 0.72 : 0.82)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Capsule()
                .fill(
                    Color(nsColor: .windowBackgroundColor)
                        .opacity(appearancePolicy.capsuleBackgroundOpacity)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    Color(nsColor: .labelColor)
                        .opacity(appearancePolicy.capsuleBorderOpacity),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
        )
        .shadow(
            color: .black.opacity(appearancePolicy.shadowOpacity),
            radius: 3,
            x: 0,
            y: 1
        )
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

    private func identityColor(for metric: PetRingMetricKind) -> Color {
        let identity = PetRingPresentationPolicy.identityColor(for: metric)
        return color(identity)
    }

    private func identityTextColor(for metric: PetRingMetricKind) -> Color {
        color(PetRingPresentationPolicy.identityTextColor(
            for: metric,
            appearance: appearance
        ))
    }

    private func color(_ identity: PetRingIdentityColor) -> Color {
        return Color(
            .sRGB,
            red: Double(identity.red) / 255,
            green: Double(identity.green) / 255,
            blue: Double(identity.blue) / 255,
            opacity: 1
        )
    }

    private var appearance: PetHaloAppearance {
        colorScheme == .dark ? .dark : .light
    }

    private var appearancePolicy: PetRingAppearancePolicy {
        .resolve(
            appearance: appearance,
            increaseContrast: colorSchemeContrast == .increased,
            reduceTransparency: reduceTransparency
        )
    }

    private var visibleMetrics: [PetRingMetricKind] {
        var metrics: [PetRingMetricKind] = [.weekly]
        if model.fiveHour != nil { metrics.append(.fiveHour) }
        if model.todayTokens != nil { metrics.append(.today) }
        return metrics
    }

    private func labelPosition(for metric: PetRingMetricKind) -> CGPoint {
        geometry.labelPosition(
            for: metric,
            side: labelSide,
            visibleMetrics: visibleMetrics
        )
    }

    private func statusSymbol(
        isStale: Bool,
        isUnavailable: Bool,
        semanticLevel: PetRingSemanticLevel?
    ) -> String? {
        if isUnavailable { return "questionmark.circle.fill" }
        if isStale { return "clock.badge.exclamationmark.fill" }
        guard differentiateWithoutColor else { return nil }
        switch semanticLevel {
        case .healthy:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case nil:
            return nil
        }
    }
}
