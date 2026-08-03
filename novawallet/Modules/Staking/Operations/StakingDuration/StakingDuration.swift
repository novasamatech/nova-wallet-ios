import Foundation

struct StakingDuration {
    let session: TimeInterval
    let era: TimeInterval
    let unlocking: UnlockingDuration
}

struct UnlockingDuration {
    let validator: TimeInterval
    let nominator: TimeInterval

    func value(for variant: UnstakingDurationVariant) -> TimeInterval {
        switch variant {
        case .full:
            validator
        case .nominator:
            nominator
        }
    }
}
