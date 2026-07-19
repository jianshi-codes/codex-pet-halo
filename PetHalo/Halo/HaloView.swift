import SwiftUI

@MainActor
final class HaloViewState: ObservableObject {
    @Published var model: HaloPresentationModel
    @Published var mode: HaloPresentationMode

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
            if differentiateWithoutColor {
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
