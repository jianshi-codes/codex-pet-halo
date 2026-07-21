import Foundation

struct WeeklyResetDateFormatter {
    private let visibleLocale: Locale
    private let accessibilityLocale: Locale
    private let timeZone: TimeZone

    init(
        visibleLocale: Locale = Locale(identifier: "en_US_POSIX"),
        accessibilityLocale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.visibleLocale = visibleLocale
        self.accessibilityLocale = accessibilityLocale
        self.timeZone = timeZone
    }

    func visibleValue(percentText: String, resetsAt: Date?) -> String {
        guard let resetsAt else { return percentText }
        return "\(percentText) · \(compactDate(resetsAt))"
    }

    func accessibilityReset(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = accessibilityLocale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        let timeZoneContext = timeZone.abbreviation(for: date) ?? timeZone.identifier
        return "\(formatter.string(from: date)) \(timeZoneContext)"
    }

    private func compactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = visibleLocale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}
