import Foundation

struct MythosSessionCollator {
    let accountId: AccountId
    let info: MythosStakingPallet.CandidateInfo?
}

typealias MythosSessionCollators = [MythosSessionCollator]
