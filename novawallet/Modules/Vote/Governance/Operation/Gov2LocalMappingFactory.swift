import Foundation
import BigInt

final class Gov2LocalMappingFactory {
    private func createDecidingState(
        from status: ReferendumInfo.OngoingStatus,
        deciding: ReferendumInfo.DecidingStatus,
        track: Referenda.TrackInfo,
        additionalInfo: Gov2OperationFactory.AdditionalInfo
    ) -> ReferendumStateLocal {
        let approvalFunction = Gov2LocalDecidingFunction(
            curve: track.minApproval,
            startBlock: deciding.since,
            period: track.decisionPeriod
        )

        let supportFunction = Gov2LocalDecidingFunction(
            curve: track.minSupport,
            startBlock: deciding.since,
            period: track.decisionPeriod
        )

        let votes = SupportAndVotesLocal(
            ayes: status.tally.ayes,
            nays: status.tally.nays,
            support: status.tally.support,
            totalIssuance: additionalInfo.totalIssuance,
            approvalFunction: approvalFunction,
            supportFunction: supportFunction
        )

        let localTrack = GovernanceTrackLocal(trackId: status.track, name: track.name)

        let deposit = deposit(from: status.submissionDeposit, decision: status.decisionDeposit)

        let model = ReferendumStateLocal.Deciding(
            track: localTrack,
            proposal: status.proposal,
            voting: .supportAndVotes(votes),
            submitted: status.submitted,
            since: deciding.since,
            period: track.decisionPeriod,
            confirmationUntil: deciding.confirming,
            deposit: deposit
        )

        return .deciding(model: model)
    }

    private func createPreparingState(
        from status: ReferendumInfo.OngoingStatus,
        index: Referenda.ReferendumIndex,
        track: Referenda.TrackInfo,
        additionalInfo: Gov2OperationFactory.AdditionalInfo,
        trackQueue: [Referenda.TrackQueueItem]?
    ) -> ReferendumStateLocal {
        let approvalFunction = Gov2LocalDecidingFunction(
            curve: track.minApproval,
            startBlock: nil,
            period: track.decisionPeriod
        )

        let supportFunction = Gov2LocalDecidingFunction(
            curve: track.minSupport,
            startBlock: nil,
            period: track.decisionPeriod
        )

        let votes = SupportAndVotesLocal(
            ayes: status.tally.ayes,
            nays: status.tally.nays,
            support: status.tally.support,
            totalIssuance: additionalInfo.totalIssuance,
            approvalFunction: approvalFunction,
            supportFunction: supportFunction
        )

        let localTrack = GovernanceTrackLocal(trackId: status.track, name: track.name)

        let inQueuePosition: ReferendumStateLocal.InQueuePosition?

        if
            status.inQueue,
            let queue = trackQueue,
            let position = queue.firstIndex(where: { $0.referendum == index }) {
            inQueuePosition = .init(index: position, total: queue.count)
        } else {
            inQueuePosition = nil
        }

        let preparing = ReferendumStateLocal.Preparing(
            track: localTrack,
            proposal: status.proposal,
            voting: .supportAndVotes(votes),
            deposit: status.decisionDeposit?.amount,
            since: status.submitted,
            preparingPeriod: track.preparePeriod,
            timeoutPeriod: additionalInfo.undecidingTimeout,
            inQueue: status.inQueue,
            inQueuePosition: inQueuePosition
        )

        return .preparing(model: preparing)
    }

    private func createOngoingReferendumState(
        from status: ReferendumInfo.OngoingStatus,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov2OperationFactory.AdditionalInfo,
        trackQueue: [Referenda.TrackQueueItem]?
    ) -> ReferendumLocal? {
        guard let track = additionalInfo.tracks[status.track] else {
            return nil
        }

        let state: ReferendumStateLocal

        if let deciding = status.deciding {
            state = createDecidingState(
                from: status,
                deciding: deciding,
                track: track,
                additionalInfo: additionalInfo
            )
        } else {
            state = createPreparingState(
                from: status,
                index: index,
                track: track,
                additionalInfo: additionalInfo,
                trackQueue: trackQueue
            )
        }

        return ReferendumLocal(index: UInt(index), state: state, proposer: status.submissionDeposit.who)
    }

    // swiftlint:disable:next function_body_length
    func mapRemote(
        referendum: ReferendumInfo,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov2OperationFactory.AdditionalInfo,
        enactmentBlock: BlockNumber?,
        inQueueState: [Referenda.TrackId: [Referenda.TrackQueueItem]]
    ) -> ReferendumLocal? {
        switch referendum {
        case let .ongoing(status):
            return createOngoingReferendumState(
                from: status,
                index: index,
                additionalInfo: additionalInfo,
                trackQueue: inQueueState[status.track]
            )
        case let .approved(status):
            let state: ReferendumStateLocal

            if let enactmentBlock = enactmentBlock {
                let value = ReferendumStateLocal.Approved(
                    since: status.since,
                    whenEnactment: enactmentBlock,
                    deposit: deposit(from: status.submissionDeposit, decision: status.decisionDeposit)
                )
                state = .approved(model: value)
            } else {
                state = .executed
            }

            return ReferendumLocal(
                index: UInt(index),
                state: state,
                proposer: status.submissionDeposit.who
            )
        case let .rejected(status):
            let value = notApproved(
                from: status.since,
                submission: status.submissionDeposit,
                decision: status.decisionDeposit
            )

            return ReferendumLocal(
                index: UInt(index),
                state: .rejected(model: value),
                proposer: status.submissionDeposit.who
            )
        case let .timedOut(status):
            let value = notApproved(
                from: status.since,
                submission: status.submissionDeposit,
                decision: status.decisionDeposit
            )

            return ReferendumLocal(
                index: UInt(index),
                state: .timedOut(model: value),
                proposer: status.submissionDeposit.who
            )
        case let .cancelled(status):
            let value = notApproved(
                from: status.since,
                submission: status.submissionDeposit,
                decision: status.decisionDeposit
            )

            return ReferendumLocal(
                index: UInt(index),
                state: .cancelled(model: value),
                proposer: status.submissionDeposit.who
            )
        case let .killed(atBlock):
            return ReferendumLocal(index: UInt(index), state: .killed(atBlock: atBlock), proposer: nil)
        case .unknown:
            return nil
        }
    }

    private func deposit(from submission: Referenda.Deposit, decision: Referenda.Deposit?) -> BigUInt {
        submission.amount + (decision?.amount ?? 0)
    }

    private func notApproved(
        from atBlock: BlockNumber,
        submission: Referenda.Deposit,
        decision: Referenda.Deposit?
    ) -> ReferendumStateLocal.NotApproved {
        let deposit = deposit(from: submission, decision: decision)
        return .init(atBlock: atBlock, deposit: deposit)
    }
}
