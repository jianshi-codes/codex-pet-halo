import SwiftUI

@MainActor
final class HaloViewState: ObservableObject {
    @Published var model: HaloPresentationModel
    @Published var mode: HaloPresentationMode
    @Published var isCalibrating = false

    init(model: HaloPresentationModel, mode: HaloPresentationMode) {
        self.model = model
        self.mode = mode
    }
}

struct HaloView: View {
    @ObservedObject var state: HaloViewState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Group {
            switch state.mode {
            case .compact:
                HaloCompactView(model: state.model)
            case .expanded:
                HaloExpandedView(model: state.model)
            }
        }
        .padding(state.mode == .compact ? 14 : 16)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: state.mode == .compact ? 36 : 22))
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
                RoundedRectangle(cornerRadius: state.mode == .compact ? 36 : 22)
                    .stroke(.primary.opacity(0.35), lineWidth: 1)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
