import Foundation

struct ReferendumLockTransitionViewModel {
    struct Change {
        let isIncrease: Bool
        let value: String
    }

    let fromValue: String
    let toValue: String
    let change: Change?
}
