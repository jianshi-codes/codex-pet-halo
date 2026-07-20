import Foundation

struct WindowFollowingPreferenceSnapshot: Equatable, Sendable {
    let followingEnabled: Bool
    let windowAnchor: HaloWindowAnchor?
    let petVisualCenterOffset: PetVisualCenterOffset

    init(
        followingEnabled: Bool,
        windowAnchor: HaloWindowAnchor?,
        petVisualCenterOffset: PetVisualCenterOffset = .zero
    ) {
        self.followingEnabled = followingEnabled
        self.windowAnchor = windowAnchor
        self.petVisualCenterOffset = petVisualCenterOffset
    }
}

@MainActor
protocol WindowFollowingPreferenceStoring: AnyObject {
    func load() -> WindowFollowingPreferenceSnapshot
    func removeLegacyPetAnchor()
    func setFollowingEnabled(_ enabled: Bool)
    func setWindowAnchor(_ anchor: HaloWindowAnchor?)
    func setPetVisualCenterOffset(_ offset: PetVisualCenterOffset)
}

@MainActor
final class UserDefaultsWindowFollowingPreferences: WindowFollowingPreferenceStoring {
    private enum Key {
        static let followingEnabled = "io.github.jianshicodes.PetHalo.windowFollowing.enabled"
        static let windowAnchor = "io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1"
        static let petAnchor = "io.github.jianshicodes.PetHalo.petFollowing.anchor.v1"
        static let petVisualCenterOffset = "io.github.jianshicodes.PetHalo.petRing.visualCenterOffset.v1"
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
        let petVisualCenterOffset = defaults.data(forKey: Key.petVisualCenterOffset)
            .flatMap { try? decoder.decode(PetVisualCenterOffset.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil }
            ?? .zero
        return WindowFollowingPreferenceSnapshot(
            followingEnabled: defaults.bool(forKey: Key.followingEnabled),
            windowAnchor: windowAnchor,
            petVisualCenterOffset: petVisualCenterOffset
        )
    }

    func removeLegacyPetAnchor() {
        defaults.removeObject(forKey: Key.petAnchor)
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

    func setPetVisualCenterOffset(_ offset: PetVisualCenterOffset) {
        guard offset.isValid, let data = try? encoder.encode(offset) else { return }
        defaults.set(data, forKey: Key.petVisualCenterOffset)
    }
}
