import Foundation

typealias MythosCandidatesInfoMapping = [AccountId: MythosStakingPallet.CandidateInfo]

struct MythosEligibleCollators {
    let invulnerables: Set<AccountId>
    let activeCandidates: Set<AccountId>
    let info: MythosCandidatesInfoMapping
}
