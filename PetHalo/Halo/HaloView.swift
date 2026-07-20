import SwiftUI

@MainActor
final class HaloViewState: ObservableObject {
    @Published var cardModel: HaloPresentationModel
    @Published var petRingModel: PetRingPresentationModel
    @Published var petRingOrientation: PetRingOrientation
    @Published var petRingLabelSide: PetRingLabelSide
    @Published var surfaceMode: HaloSurfaceMode
    @Published var isCalibrating = false

    init(
        cardModel: HaloPresentationModel,
        petRingModel: PetRingPresentationModel,
        petRingOrientation: PetRingOrientation = .fixedDefault,
        petRingLabelSide: PetRingLabelSide = .right,
        surfaceMode: HaloSurfaceMode
    ) {
        self.cardModel = cardModel
        self.petRingModel = petRingModel
        self.petRingOrientation = petRingOrientation
        self.petRingLabelSide = petRingLabelSide
        self.surfaceMode = surfaceMode
    }
}

struct HaloView: View {
    @ObservedObject var state: HaloViewState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Group {
            switch state.surfaceMode {
            case .petRing:
                PetRingView(
                    model: state.petRingModel,
                    orientation: state.petRingOrientation,
                    labelSide: state.petRingLabelSide,
                    isCalibrating: state.isCalibrating
                )
            case .compactCard:
                cardSurface(cornerRadius: 36, padding: 14) {
                    HaloCompactView(model: state.cardModel)
                }
            case .expandedCard:
                cardSurface(cornerRadius: 22, padding: 16) {
                    HaloExpandedView(model: state.cardModel)
                }
            }
        }
    }

    private func cardSurface<Content: View>(
        cornerRadius: CGFloat,
        padding: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if state.isCalibrating {
                    VStack {
                        Spacer()
                        Text("Position Halo, then finish calibration from the menu bar")
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                    }
                    .accessibilityLabel("Calibration active")
                } else if differentiateWithoutColor {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.primary.opacity(0.35), lineWidth: 1)
                        .accessibilityHidden(true)
                }
            }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
