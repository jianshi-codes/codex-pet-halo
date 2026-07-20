import SwiftUI

private struct PetRingArc: Shape {
    let startAngleDegrees: Double
    let sweepAngleDegrees: Double
    let radius: Double
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
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

    init(
        model: PetRingPresentationModel,
        geometry: PetRingGeometry = .standard
    ) {
        self.model = model
        self.geometry = geometry
    }

    var body: some View {
        ZStack {
            primaryArcs
            secondaryArc
            labels
        }
        .frame(width: geometry.panelDiameter, height: geometry.panelDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pet Halo usage ring")
        .accessibilityValue(model.accessibilityValue)
    }

    private var primaryArcs: some View {
        ZStack {
            PetRingArc(
                startAngleDegrees: geometry.startAngleDegrees,
                sweepAngleDegrees: geometry.sweepAngleDegrees,
                radius: geometry.radius,
                progress: 1
            )
            .stroke(.secondary.opacity(0.25), lineWidth: geometry.primaryLineWidth)

            if let value = model.weekly.value {
                PetRingArc(
                    startAngleDegrees: geometry.startAngleDegrees,
                    sweepAngleDegrees: geometry.sweepAngleDegrees,
                    radius: geometry.radius,
                    progress: value.progress
                )
                .stroke(
                    .primary,
                    style: StrokeStyle(
                        lineWidth: geometry.primaryLineWidth,
                        lineCap: .round,
                        dash: model.weekly.isStale ? [5, 4] : []
                    )
                )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var secondaryArc: some View {
        if let fiveHour = model.fiveHour, let value = fiveHour.value {
            PetRingArc(
                startAngleDegrees: geometry.startAngleDegrees,
                sweepAngleDegrees: geometry.sweepAngleDegrees,
                radius: geometry.radius - geometry.primaryLineWidth,
                progress: value.progress
            )
            .stroke(
                .secondary,
                style: StrokeStyle(
                    lineWidth: geometry.secondaryLineWidth,
                    lineCap: .round,
                    dash: fiveHour.isStale ? [3, 3] : []
                )
            )
            .accessibilityHidden(true)
        }
    }

    private var labels: some View {
        GeometryReader { proxy in
            weeklyLabel
                .position(x: proxy.size.width / 2, y: 8)

            if let fiveHour = model.fiveHour {
                metricLabel(prefix: "5h", metric: fiveHour)
                    .position(x: proxy.size.width * 0.23, y: proxy.size.height - 8)
            }

            if let todayTokens = model.todayTokens {
                todayLabel(todayTokens)
                    .position(x: proxy.size.width * 0.76, y: proxy.size.height - 8)
            }
        }
        .font(.caption2.monospacedDigit().weight(.semibold))
    }

    private var weeklyLabel: some View {
        metricLabel(prefix: "W", metric: model.weekly)
    }

    private func metricLabel(
        prefix: String,
        metric: RingMetricPresentation
    ) -> some View {
        let valueText = metric.value?.percentText ?? "—"
        let levelText = metric.value.map { $0.remainingLevel == .normal ? "" : " \($0.remainingLevel.text)" }
            ?? ""
        let staleText = metric.isStale ? " Stale" : ""
        return Text("\(prefix) \(valueText)\(levelText)\(staleText)")
    }

    private func todayLabel(_ metric: TodayTokenPresentation) -> some View {
        let valueText = metric.value?.tokenText ?? "—"
        let staleText = metric.isStale ? " Stale" : ""
        return Text("Today \(valueText)\(staleText)")
    }
}
