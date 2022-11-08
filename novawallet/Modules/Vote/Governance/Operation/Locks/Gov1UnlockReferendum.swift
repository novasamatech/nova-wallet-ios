import Foundation

final class Gov1UnlockReferendum {
    let referendum: Democracy.ReferendumInfo

    init(referendum: Democracy.ReferendumInfo) {
        self.referendum = referendum
    }
}

extension Gov1UnlockReferendum: GovUnlockReferendumProtocol {
    func estimateVoteLockingPeriod(
        for accountVote: ReferendumAccountVoteLocal,
        additionalInfo: GovUnlockCalculationInfo
    ) throws -> BlockNumber? {
        let conviction = accountVote.convictionValue

        guard let convictionPeriod = conviction.conviction(for: additionalInfo.voteLockingPeriod) else {
            throw CommonError.dataCorruption
        }

        switch referendum {
        case let .ongoing(status):
            return status.end + convictionPeriod
        case let .finished(status):
            if status.approved, accountVote.hasAyeVotes {
                return status.end + convictionPeriod
            } else if !status.approved, accountVote.hasNayVotes {
                return status.end + convictionPeriod
            } else {
                return nil
            }
        case .unknown:
            return nil
        }
    }
}
