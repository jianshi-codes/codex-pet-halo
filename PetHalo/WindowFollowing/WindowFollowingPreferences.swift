import Foundation

struct WindowFollowingPreferenceSnapshot: Equatable, Sendable {
    let followingEnabled: Bool
    let anchor: HaloWindowAnchor?
}

@MainActor
protocol WindowFollowingPreferenceStoring: AnyObject {
    func load() -> WindowFollowingPreferenceSnapshot
    func setFollowingEnabled(_ enabled: Bool)
    func setAnchor(_ anchor: HaloWindowAnchor?)
}

@MainActor
final class UserDefaultsWindowFollowingPreferences: WindowFollowingPreferenceStoring {
    private enum Key {
        static let followingEnabled = "io.github.jianshicodes.PetHalo.windowFollowing.enabled"
        static let anchor = "io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WindowFollowingPreferenceSnapshot {
        let anchor = defaults.data(forKey: Key.anchor)
            .flatMap { try? decoder.decode(HaloWindowAnchor.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil }
        return WindowFollowingPreferenceSnapshot(
            followingEnabled: defaults.bool(forKey: Key.followingEnabled),
            anchor: anchor
        )
    }

    func setFollowingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.followingEnabled)
    }

    func setAnchor(_ anchor: HaloWindowAnchor?) {
        guard let anchor else {
            defaults.removeObject(forKey: Key.anchor)
            return
        }
        guard anchor.isValid, let data = try? encoder.encode(anchor) else { return }
        defaults.set(data, forKey: Key.anchor)
    }
}
