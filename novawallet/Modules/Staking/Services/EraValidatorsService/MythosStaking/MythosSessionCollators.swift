import Foundation

struct MythosSessionCollator {
    let accountId: AccountId
    let info: MythosStakingPallet.CandidateInfo?
    let invulnerable: Bool

    var rewardable: Bool {
        !invulnerable
    }
}

typealias MythosSessionCollators = [MythosSessionCollator]
