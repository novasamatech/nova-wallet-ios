import Foundation

enum AssetVisibilityEvent {
    case userSet(isVisible: Bool)
    case passivePositiveBalance(autoAddEnabled: Bool)
    case userInitiatedReceipt
}

enum AssetVisibilityDecision: Equatable {
    case noChange
    case set(AssetVisibilityState)
}

enum AssetVisibilityPolicy {
    static func isVisible(state: AssetVisibilityState?, isDefault: Bool) -> Bool {
        switch state {
        case .visible:
            true
        case .hidden:
            false
        case nil:
            isDefault
        }
    }

    static func decision(
        for event: AssetVisibilityEvent,
        currentState: AssetVisibilityState?
    ) -> AssetVisibilityDecision {
        let targetState: AssetVisibilityState

        switch event {
        case let .userSet(isVisible):
            targetState = isVisible ? .visible : .hidden
        case .userInitiatedReceipt:
            targetState = .visible
        case let .passivePositiveBalance(autoAddEnabled):
            guard autoAddEnabled, currentState != .hidden else {
                return .noChange
            }

            targetState = .visible
        }

        return currentState == targetState ? .noChange : .set(targetState)
    }
}
