import Foundation

final class Gov2UnlockReferendum {
    let referendumInfo: ReferendumInfo

    init(referendumInfo: ReferendumInfo) {
        self.referendumInfo = referendumInfo
    }
}

extension Gov2UnlockReferendum: GovUnlockReferendumProtocol {
    func estimateVoteLockingPeriod(
        for accountVote: ReferendumAccountVoteLocal,
        additionalInfo: GovUnlockCalculationInfo
    ) throws -> BlockNumber? {
        let conviction = accountVote.convictionValue

        guard let convictionPeriod = conviction.conviction(for: additionalInfo.voteLockingPeriod) else {
            throw CommonError.dataCorruption
        }

        switch referendumInfo {
        case let .ongoing(ongoingStatus):
            guard let decisionPeriod = additionalInfo.decisionPeriods[ongoingStatus.track] else {
                return nil
            }

            if let decidingSince = ongoingStatus.deciding?.since {
                return decidingSince + decisionPeriod + convictionPeriod
            } else {
                return ongoingStatus.submitted + additionalInfo.undecidingTimeout +
                    decisionPeriod + convictionPeriod
            }
        case let .approved(completedStatus):
            if accountVote.hasAyeVotes {
                return completedStatus.since + convictionPeriod
            } else {
                return nil
            }
        case let .rejected(completedStatus):
            if accountVote.hasNayVotes {
                return completedStatus.since + convictionPeriod
            } else {
                return nil
            }
        case .killed, .timedOut, .cancelled:
            return nil
        case .unknown:
            throw CommonError.dataCorruption
        }
    }
}
