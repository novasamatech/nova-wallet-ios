import Foundation

struct GovernanceUnlockInitData {
    let votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    let unlockSchedule: GovernanceUnlockSchedule?
    let blockNumber: BlockNumber?
    let blockTime: BlockTime?
}
