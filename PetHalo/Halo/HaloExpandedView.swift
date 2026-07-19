import SwiftUI

struct HaloExpandedView: View {
    let model: HaloPresentationModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Usage")
                        .font(.headline)
                    Spacer()
                    Text(model.connectionState.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connection")
                .accessibilityValue(model.connectionState.text)

                quotaSection(title: "Weekly", state: model.weekly)
                if let fiveHour = model.fiveHour {
                    quotaSection(title: "Five-hour", state: fiveHour)
                }

                Divider()
                accountUsageSection
            }
        }
    }

    private func quotaSection(
        title: String,
        state: HaloMetricState<QuotaPresentation>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let quota = state.value {
                Text("\(quota.remainingText) remaining")
                    .font(.title3.monospacedDigit())
                Text(quota.resetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Unavailable")
                    .font(.body)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) quota")
        .accessibilityValue(HaloAccessibility.metricValue(name: "\(title) quota", state: state))
    }

    @ViewBuilder
    private var accountUsageSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Account Usage")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.accountUsage.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let usage = model.accountUsage.value {
                ForEach(usage.summaryRows) { row in
                    rowView(label: row.label, value: row.value)
                }
                if !usage.dailyRows.isEmpty {
                    Text("Recent days")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 3)
                    ForEach(usage.dailyRows) { row in
                        rowView(label: row.dateText, value: row.tokenText)
                    }
                }
                if usage.summaryRows.isEmpty, usage.dailyRows.isEmpty {
                    Text("No Usage fields available")
                        .font(.body)
                }
            } else {
                Text("Account Usage unavailable")
                    .font(.body)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Account Usage")
        .accessibilityValue(HaloAccessibility.accountUsageValue(model.accountUsage))
    }

    private func rowView(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.trailing)
        }
    }
}
