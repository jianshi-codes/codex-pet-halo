import AppKit
import SwiftUI

@MainActor
protocol HaloPanelControlling: AnyObject {
    var isVisible: Bool { get }
    var mode: HaloPresentationMode { get }

    func show()
    func hide()
    func setMode(_ mode: HaloPresentationMode)
    func update(model: HaloPresentationModel)
    func stop()
}

@MainActor
final class HaloPanelController: HaloPanelControlling {
    static let compactSize = NSSize(width: 176, height: 176)
    static let expandedSize = NSSize(width: 360, height: 520)

    private(set) var panel: HaloPanel?
    private(set) var mode: HaloPresentationMode = .compact
    private let viewState: HaloViewState
    private let visibleFrameProvider: () -> NSRect
    private var stopped = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    init(
        model: HaloPresentationModel = .starting,
        visibleFrameProvider: @escaping () -> NSRect = {
            (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: 1_024, height: 768)
        }
    ) {
        viewState = HaloViewState(model: model, mode: .compact)
        self.visibleFrameProvider = visibleFrameProvider

        let frame = Self.defaultFrame(
            size: Self.compactSize,
            visibleFrame: visibleFrameProvider()
        )
        let panel = HaloPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.title = "Pet Halo"
        panel.contentView = NSHostingView(rootView: HaloView(state: viewState))
        self.panel = panel
    }

    func show() {
        guard !stopped, let panel, !panel.isVisible else { return }
        panel.orderFrontRegardless()
    }

    func hide() {
        guard !stopped, let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    func setMode(_ mode: HaloPresentationMode) {
        guard !stopped, let panel else { return }
        guard self.mode != mode else { return }
        self.mode = mode
        viewState.mode = mode

        let size = Self.size(for: mode)
        let oldFrame = panel.frame
        let proposed = NSRect(
            x: oldFrame.maxX - size.width,
            y: oldFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(
            Self.frame(proposed, containedIn: visibleFrameProvider()),
            display: true
        )
    }

    func update(model: HaloPresentationModel) {
        guard !stopped else { return }
        viewState.model = model
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        panel?.orderOut(nil)
        panel?.close()
        panel?.contentView = nil
        panel = nil
    }

    static func size(for mode: HaloPresentationMode) -> NSSize {
        switch mode {
        case .compact:
            compactSize
        case .expanded:
            expandedSize
        }
    }

    static func defaultFrame(size: NSSize, visibleFrame: NSRect) -> NSRect {
        let inset: CGFloat = 24
        let proposed = NSRect(
            x: visibleFrame.maxX - size.width - inset,
            y: visibleFrame.maxY - size.height - inset,
            width: size.width,
            height: size.height
        )
        return frame(proposed, containedIn: visibleFrame)
    }

    private static func frame(_ proposed: NSRect, containedIn visibleFrame: NSRect) -> NSRect {
        let width = min(proposed.width, visibleFrame.width)
        let height = min(proposed.height, visibleFrame.height)
        let minimumX = visibleFrame.minX
        let maximumX = max(minimumX, visibleFrame.maxX - width)
        let minimumY = visibleFrame.minY
        let maximumY = max(minimumY, visibleFrame.maxY - height)
        return NSRect(
            x: min(max(proposed.origin.x, minimumX), maximumX),
            y: min(max(proposed.origin.y, minimumY), maximumY),
            width: width,
            height: height
        )
    }
}
