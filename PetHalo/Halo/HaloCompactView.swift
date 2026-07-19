import SwiftUI

struct HaloCompactView: View {
    let model: HaloPresentationModel

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.22), lineWidth: 10)
                .accessibilityHidden(true)

            if let quota = model.weekly.value {
                Circle()
                    .trim(from: 0, to: quota.gaugeFraction)
                    .stroke(
                        .primary.opacity(0.75),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .accessibilityHidden(true)
            }

            VStack(spacing: 3) {
                Text("Week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                weeklyValue

                if let fiveHour = model.fiveHour {
                    Text("5h \(fiveHour.value?.remainingText ?? "Unavailable")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if case .stale = fiveHour {
                        Text("Stale")
                            .font(.caption2)
                    }
                }
            }
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pet Halo usage")
        .accessibilityValue(HaloAccessibility.compactValue(model))
    }

    @ViewBuilder
    private var weeklyValue: some View {
        switch model.weekly {
        case let .current(quota):
            Text(quota.remainingText)
                .font(.title2.monospacedDigit().weight(.semibold))
        case let .stale(quota):
            Text(quota.remainingText)
                .font(.title2.monospacedDigit().weight(.semibold))
            Text("Stale")
                .font(.caption2.weight(.semibold))
        case .unavailable:
            Text(model.connectionState.text)
                .font(.callout.weight(.semibold))
        }
    }
}
