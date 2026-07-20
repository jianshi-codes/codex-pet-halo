import AppKit
import QuartzCore

struct PetFrameFollowerPolicy: Equatable, Sendable {
    let snapDistance: Double
    let discontinuityDistance: Double
    let stableRefreshCount: Int

    func shouldSnap(current: CGRect, target: CGRect, reduceMotion: Bool) -> Bool {
        let distance = distance(from: current, to: target)
        return reduceMotion || distance <= snapDistance || distance >= discontinuityDistance
    }

    func distance(from current: CGRect, to target: CGRect) -> Double {
        hypot(target.origin.x - current.origin.x, target.origin.y - current.origin.y)
    }

    static let standard = PetFrameFollowerPolicy(
        snapDistance: 1.25,
        discontinuityDistance: 96,
        stableRefreshCount: 4
    )
}

@MainActor
protocol DisplayLinkDriving: AnyObject {
    func start(callback: @escaping @MainActor () -> Void)
    func setPaused(_ paused: Bool)
    func stop()
}

@MainActor
final class WindowDisplayLinkDriver: NSObject, DisplayLinkDriving {
    private weak var window: NSWindow?
    private var displayLink: CADisplayLink?
    private var callback: (@MainActor () -> Void)?

    init(window: NSWindow) {
        self.window = window
    }

    func start(callback: @escaping @MainActor () -> Void) {
        self.callback = callback
        guard displayLink == nil, let window else { return }
        let displayLink = window.displayLink(
            target: self,
            selector: #selector(displayLinkDidFire(_:))
        )
        displayLink.add(to: .main, forMode: .common)
        displayLink.isPaused = true
        self.displayLink = displayLink
    }

    func setPaused(_ paused: Bool) {
        displayLink?.isPaused = paused
    }

    func stop() {
        callback = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkDidFire(_: CADisplayLink) {
        callback?()
    }
}

@MainActor
final class PetFrameFollower {
    private let policy: PetFrameFollowerPolicy
    private let displayLink: any DisplayLinkDriving
    private let reduceMotion: () -> Bool
    private let sampleLatest: () -> PetAttachmentLayout?
    private let apply: (PetAttachmentLayout) -> Void
    private var currentFrame: CGRect?
    private var latestLayout: PetAttachmentLayout?
    private var displayLinkStarted = false
    private var stableRefreshCount = 0
    private var stopped = false

    init(
        policy: PetFrameFollowerPolicy = .standard,
        displayLink: any DisplayLinkDriving,
        reduceMotion: @escaping () -> Bool,
        sampleLatest: @escaping () -> PetAttachmentLayout? = { nil },
        apply: @escaping (PetAttachmentLayout) -> Void
    ) {
        self.policy = policy
        self.displayLink = displayLink
        self.reduceMotion = reduceMotion
        self.sampleLatest = sampleLatest
        self.apply = apply
    }

    func snap(to layout: PetAttachmentLayout) {
        guard !stopped else { return }
        latestLayout = layout
        currentFrame = layout.panelFrame
        stableRefreshCount = 0
        displayLink.setPaused(true)
        apply(layout)
    }

    func follow(to layout: PetAttachmentLayout) {
        guard !stopped else { return }
        latestLayout = layout
        stableRefreshCount = 0
        guard let currentFrame else {
            snap(to: layout)
            return
        }
        if policy.shouldSnap(
            current: currentFrame,
            target: layout.panelFrame,
            reduceMotion: reduceMotion()
        ) {
            snap(to: layout)
            return
        }
        startDisplayLinkIfNeeded()
        displayLink.setPaused(false)
    }

    func pause() {
        guard !stopped else { return }
        displayLink.setPaused(true)
    }

    func reset() {
        guard !stopped else { return }
        latestLayout = nil
        currentFrame = nil
        stableRefreshCount = 0
        displayLink.setPaused(true)
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        latestLayout = nil
        currentFrame = nil
        displayLink.stop()
    }

    private func startDisplayLinkIfNeeded() {
        guard !displayLinkStarted else { return }
        displayLinkStarted = true
        displayLink.start { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        guard !stopped,
              let currentFrame,
              let pendingLayout = latestLayout
        else {
            displayLink.setPaused(true)
            return
        }
        let newestLayout = sampleLatest() ?? pendingLayout
        latestLayout = newestLayout
        if newestLayout.panelFrame == currentFrame {
            stableRefreshCount += 1
        } else {
            stableRefreshCount = 0
            self.currentFrame = newestLayout.panelFrame
            apply(newestLayout)
        }
        if stableRefreshCount >= policy.stableRefreshCount {
            displayLink.setPaused(true)
        }
    }
}
