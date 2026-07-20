import AppKit
import SwiftUI

@MainActor
protocol HaloPanelControlling: AnyObject {
    var isVisible: Bool { get }
    var mode: HaloPresentationMode { get }
    var surfaceMode: HaloSurfaceMode { get }
    var referencePoint: CGPoint { get }
    var frame: CGRect { get }
    var isCalibrationEnabled: Bool { get }
    var attachmentLayout: PetAttachmentLayout? { get }

    func show()
    func hide()
    func setMode(_ mode: HaloPresentationMode)
    func setSurfaceMode(_ mode: HaloSurfaceMode)
    func setReferencePoint(_ referencePoint: CGPoint)
    func setAttachmentLayout(_ layout: PetAttachmentLayout)
    func setCalibrationEnabled(_ enabled: Bool)
    func resetToDefaultPosition()
    func update(
        cardModel: HaloPresentationModel,
        petRingModel: PetRingPresentationModel
    )
    func stop()
}

@MainActor
final class HaloPanelController: HaloPanelControlling {
    static let compactSize = NSSize(width: 176, height: 176)
    static let expandedSize = NSSize(width: 360, height: 520)
    static let petRingSize = NSSize(
        width: PetRingGeometry.standard.panelDiameter,
        height: PetRingGeometry.standard.panelDiameter
    )

    private(set) var panel: HaloPanel?
    private(set) var mode: HaloPresentationMode = .compact
    private(set) var surfaceMode: HaloSurfaceMode = .compactCard
    private(set) var isCalibrationEnabled = false
    private let viewState: HaloViewState
    private let visibleFrameProvider: () -> NSRect
    private let screenGeometryProvider: () -> [ScreenGeometry]
    private var desiredReferencePoint = CGPoint.zero
    private(set) var attachmentLayout: PetAttachmentLayout?
    private var stopped = false

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var referencePoint: CGPoint {
        panel.map { HaloPlacementGeometry.referencePoint(for: $0.frame) } ?? .zero
    }

    var frame: CGRect {
        panel?.frame ?? .zero
    }

    init(
        model: HaloPresentationModel = .starting,
        visibleFrameProvider: @escaping () -> NSRect = {
            (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: 1_024, height: 768)
        },
        screenGeometryProvider: (() -> [ScreenGeometry])? = nil
    ) {
        viewState = HaloViewState(
            cardModel: model,
            petRingModel: .starting,
            surfaceMode: .compactCard
        )
        self.visibleFrameProvider = visibleFrameProvider
        self.screenGeometryProvider = screenGeometryProvider ?? {
            let screens = NSScreen.screens.map {
                ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame)
            }
            if !screens.isEmpty {
                return screens
            }
            let visibleFrame = visibleFrameProvider()
            return [ScreenGeometry(frame: visibleFrame, visibleFrame: visibleFrame)]
        }

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
        panel.calibrationDragHandler = { [weak self] origin in
            self?.moveCalibration(to: origin)
        }
        self.panel = panel
        desiredReferencePoint = HaloPlacementGeometry.referencePoint(for: frame)
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
        guard !stopped else { return }
        self.mode = mode
        setSurfaceMode(HaloSurfaceMode(cardMode: mode))
    }

    func setSurfaceMode(_ mode: HaloSurfaceMode) {
        guard !stopped, let panel else { return }
        guard surfaceMode != mode else { return }
        surfaceMode = mode
        if let cardMode = mode.cardMode {
            self.mode = cardMode
        } else {
            isCalibrationEnabled = false
            viewState.isCalibrating = false
            panel.calibrationEnabled = false
        }
        viewState.surfaceMode = mode
        panel.hasShadow = mode.hasPanelShadow
        updateMousePolicy(panel: panel)

        let size = Self.size(for: mode)
        setFrame(referencePoint: desiredReferencePoint, size: size)
    }

    func setReferencePoint(_ referencePoint: CGPoint) {
        guard !stopped, panel != nil else { return }
        attachmentLayout = nil
        desiredReferencePoint = referencePoint
        setFrame(referencePoint: referencePoint, size: Self.size(for: surfaceMode))
    }

    func setAttachmentLayout(_ layout: PetAttachmentLayout) {
        guard !stopped,
              let panel,
              layout.referencePoint.x.isFinite,
              layout.referencePoint.y.isFinite,
              layout.panelFrame.origin.x.isFinite,
              layout.panelFrame.origin.y.isFinite,
              layout.panelFrame.width.isFinite,
              layout.panelFrame.height.isFinite,
              layout.panelFrame.width > 0,
              layout.panelFrame.height > 0
        else {
            return
        }
        attachmentLayout = layout
        desiredReferencePoint = layout.referencePoint
        panel.setFrame(layout.panelFrame, display: true)
    }

    func setCalibrationEnabled(_ enabled: Bool) {
        guard !stopped, let panel, isCalibrationEnabled != enabled else { return }
        isCalibrationEnabled = enabled
        viewState.isCalibrating = enabled
        panel.calibrationEnabled = enabled
        updateMousePolicy(panel: panel)
    }

    func resetToDefaultPosition() {
        guard !stopped, let panel else { return }
        attachmentLayout = nil
        panel.setFrame(
            Self.defaultFrame(
                size: Self.size(for: surfaceMode),
                visibleFrame: visibleFrameProvider()
            ),
            display: true
        )
        desiredReferencePoint = HaloPlacementGeometry.referencePoint(for: panel.frame)
    }

    func update(
        cardModel: HaloPresentationModel,
        petRingModel: PetRingPresentationModel
    ) {
        guard !stopped else { return }
        viewState.cardModel = cardModel
        viewState.petRingModel = petRingModel
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        panel?.calibrationEnabled = false
        panel?.calibrationDragHandler = nil
        panel?.orderOut(nil)
        panel?.close()
        panel?.contentView = nil
        panel = nil
    }

    static func size(for mode: HaloPresentationMode) -> NSSize {
        size(for: HaloSurfaceMode(cardMode: mode))
    }

    static func size(for mode: HaloSurfaceMode) -> NSSize {
        switch mode {
        case .petRing:
            petRingSize
        case .compactCard:
            compactSize
        case .expandedCard:
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

    private func setFrame(referencePoint: CGPoint, size: CGSize) {
        guard let panel,
              let frame = HaloPlacementGeometry.containedFrame(
                  referencePoint: referencePoint,
                  size: size,
                  screens: screenGeometryProvider()
              )
        else {
            return
        }
        panel.setFrame(frame, display: true)
    }

    private func moveCalibration(to proposedOrigin: NSPoint) {
        guard isCalibrationEnabled, let panel else { return }
        attachmentLayout = nil
        let referencePoint = CGPoint(
            x: proposedOrigin.x + panel.frame.width,
            y: proposedOrigin.y + panel.frame.height
        )
        setFrame(referencePoint: referencePoint, size: panel.frame.size)
        desiredReferencePoint = self.referencePoint
    }

    private func updateMousePolicy(panel: HaloPanel) {
        if surfaceMode == .petRing {
            panel.ignoresMouseEvents = true
        } else if isCalibrationEnabled {
            panel.ignoresMouseEvents = false
        } else {
            panel.ignoresMouseEvents = surfaceMode != .expandedCard
        }
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
