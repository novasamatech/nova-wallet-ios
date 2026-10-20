import Foundation
import SubstrateSdk

struct SubtensorSubmissionFinalizer {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let netuids: Set<UInt16>?
    let novaFeeBeneficiary: AccountId?
    let submissionMarkers: [SubtensorRecordingSigner]
    let eventCenter: EventCenterProtocol
    let errorMapper: SubtensorErrorMapping

    var hasSubmitted: Bool {
        submissionMarkers.contains { $0.hasSignature }
    }

    func failure(for error: Error) -> SubtensorSubmissionFailure {
        if let failure = error as? SubtensorSubmissionFailure {
            return failure
        }

        let mappedError = errorMapper.mapSubmission(error: error)

        guard hasSubmitted, !Self.isFirstSendRejection(mappedError) else {
            return SubtensorSubmissionFailure(stage: .notSubmitted, error: mappedError)
        }

        notifyStakeChanged()

        return SubtensorSubmissionFailure(stage: .unconfirmed(extrinsicHash: nil), error: mappedError)
    }

    func dispatchFailure(for failure: SubstrateExtrinsicStatus.FailedExtrinsic) -> SubtensorSubmissionFailure {
        SubtensorSubmissionFailure(
            stage: .dispatched(blockHash: failure.blockHash, extrinsicHash: failure.extrinsicHash),
            error: errorMapper.mapSubmission(error: failure.error)
        )
    }

    func complete(
        operation: SubtensorOperation,
        success: SubstrateExtrinsicStatus.SuccessExtrinsic,
        codingFactory: RuntimeCoderFactoryProtocol?
    ) -> SubtensorOperationOutcome {
        let outcome: SubtensorOperationOutcome

        if let codingFactory {
            let parser = SubtensorOutcomeParser(
                coldkey: accountId,
                novaFeeBeneficiary: novaFeeBeneficiary,
                codingFactory: codingFactory
            )

            outcome = parser.parse(
                events: success.interestedEvents,
                for: operation,
                extrinsicHash: success.extrinsicHash,
                blockHash: success.blockHash
            )
        } else {
            outcome = SubtensorOperationOutcome(
                executed: nil,
                novaFeePaid: nil,
                alphaFeePaid: nil,
                networkFeePaid: nil,
                extrinsicHash: success.extrinsicHash,
                blockHash: success.blockHash
            )
        }

        notifyStakeChanged()

        return outcome
    }
}

extension SubtensorSubmissionFinalizer {
    static func isFirstSendRejection(_ error: Error) -> Bool {
        switch error as? SubtensorSubmissionError {
        case .feeUnpayable, .coldkeySwapInProgress:
            true
        default:
            false
        }
    }

    func notifyStakeChanged() {
        eventCenter.notify(
            with: SubtensorStakeChanged(chainAssetId: chainAssetId, accountId: accountId, netuids: netuids)
        )
    }
}
