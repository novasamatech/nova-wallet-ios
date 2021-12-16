import Foundation

enum NominationViewStatus {
    case undefined
    case active
    case inactive
    case waiting(eraCountdown: EraCountdown?, nominationEra: EraIndex)
}

struct NominationViewModel {
    let totalStakedAmount: String
    let totalStakedPrice: String
    let status: NominationViewStatus
    let hasPrice: Bool
}
