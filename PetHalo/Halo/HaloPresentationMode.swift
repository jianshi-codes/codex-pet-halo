enum HaloPresentationMode: Equatable {
    case compact
    case expanded
}

enum HaloSurfaceMode: Equatable {
    case petRing
    case compactCard
    case expandedCard

    init(cardMode: HaloPresentationMode) {
        switch cardMode {
        case .compact:
            self = .compactCard
        case .expanded:
            self = .expandedCard
        }
    }

    var cardMode: HaloPresentationMode? {
        switch self {
        case .petRing:
            nil
        case .compactCard:
            .compact
        case .expandedCard:
            .expanded
        }
    }

    var usesCardBackground: Bool {
        self != .petRing
    }

    var hasPanelShadow: Bool {
        self != .petRing
    }
}
