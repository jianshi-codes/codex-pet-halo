import Foundation

struct WindowFollowingPreferenceSnapshot: Equatable, Sendable {
    let followingEnabled: Bool
    let windowAnchor: HaloWindowAnchor?
    let petAnchor: PetRelativeAnchor?
}

@MainActor
protocol WindowFollowingPreferenceStoring: AnyObject {
    func load() -> WindowFollowingPreferenceSnapshot
    func setFollowingEnabled(_ enabled: Bool)
    func setWindowAnchor(_ anchor: HaloWindowAnchor?)
    func setPetAnchor(_ anchor: PetRelativeAnchor?)
}

@MainActor
final class UserDefaultsWindowFollowingPreferences: WindowFollowingPreferenceStoring {
    private enum Key {
        static let followingEnabled = "io.github.jianshicodes.PetHalo.windowFollowing.enabled"
        static let windowAnchor = "io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1"
        static let petAnchor = "io.github.jianshicodes.PetHalo.petFollowing.anchor.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WindowFollowingPreferenceSnapshot {
        let windowAnchor = defaults.data(forKey: Key.windowAnchor)
            .flatMap { try? decoder.decode(HaloWindowAnchor.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil }
        let petAnchor = defaults.data(forKey: Key.petAnchor)
            .flatMap { try? decoder.decode(PetRelativeAnchor.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil }
        return WindowFollowingPreferenceSnapshot(
            followingEnabled: defaults.bool(forKey: Key.followingEnabled),
            windowAnchor: windowAnchor,
            petAnchor: petAnchor
        )
    }

    func setFollowingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.followingEnabled)
    }

    func setWindowAnchor(_ anchor: HaloWindowAnchor?) {
        guard let anchor else {
            defaults.removeObject(forKey: Key.windowAnchor)
            return
        }
        guard anchor.isValid, let data = try? encoder.encode(anchor) else { return }
        defaults.set(data, forKey: Key.windowAnchor)
    }

    func setPetAnchor(_ anchor: PetRelativeAnchor?) {
        guard let anchor else {
            defaults.removeObject(forKey: Key.petAnchor)
            return
        }
        guard anchor.isValid, let data = try? encoder.encode(anchor) else { return }
        defaults.set(data, forKey: Key.petAnchor)
    }
}
