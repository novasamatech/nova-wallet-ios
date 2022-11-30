import Foundation

struct GovernanceUnlockConfirmInitData {
    let votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    let unlockSchedule: GovernanceUnlockSchedule
    let blockNumber: BlockNumber
}
