import Foundation

struct CompactTokenFormatter: Sendable {
    private let localeIdentifier: String

    init(locale: Locale = .autoupdatingCurrent) {
        localeIdentifier = locale.identifier
    }

    func string(from value: UInt64) -> String {
        let scale: (divisor: Double, suffix: String)?
        switch value {
        case 1_000_000_000...:
            scale = (1_000_000_000, "B")
        case 1_000_000...:
            scale = (1_000_000, "M")
        case 1_000...:
            scale = (1_000, "K")
        default:
            scale = nil
        }

        guard let scale else {
            return decimalFormatter(maximumFractionDigits: 0)
                .string(from: NSNumber(value: value)) ?? String(value)
        }
        let compactValue = Double(value) / scale.divisor
        let number = decimalFormatter(maximumFractionDigits: 1)
            .string(from: NSNumber(value: compactValue)) ?? String(compactValue)
        return number + scale.suffix
    }

    private func decimalFormatter(maximumFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter
    }
}
