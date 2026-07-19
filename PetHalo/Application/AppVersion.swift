import Foundation

struct AppVersion: Equatable {
    let marketingVersion: String
    let buildNumber: String

    var displayText: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }

    static func current(bundle: Bundle = .main) -> AppVersion {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    static func from(infoDictionary: [String: Any]) -> AppVersion {
        let marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "Unavailable"
        let buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "Unavailable"
        return AppVersion(marketingVersion: marketingVersion, buildNumber: buildNumber)
    }
}
