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
    func shieldedFailure(for error: Error) -> SubtensorSubmissionFailure {
        guard let shieldError = error as? SubtensorShieldError else {
            return failure(for: error)
        }

        if case let .carrierRejected(rejection) = shieldError {
            let mappedRejection = errorMapper.mapSubmission(error: rejection)

            if Self.isFirstSendRejection(mappedRejection) {
                return SubtensorSubmissionFailure(stage: .notSubmitted, error: mappedRejection)
            }
        }

        return SubtensorSubmissionFailure(stage: .notSubmitted, error: SubtensorSubmissionError.shieldedNotExecuted)
    }

    func shieldedOutcome(
        for submission: SubtensorShieldedSubmission,
        operation: SubtensorOperation,
        codingFactory: RuntimeCoderFactoryProtocol?
    ) throws -> SubtensorOperationOutcome {
        switch submission {
        case let .executed(.success(inner), carrier):
            let outcome = complete(operation: operation, success: inner, codingFactory: codingFactory)

            switch carrier {
            case let .found(carrierSuccess):
                return outcome.addingNetworkFee(
                    carrierFee(of: carrierSuccess, operation: operation, codingFactory: codingFactory)
                )
            case .absent:
                return outcome
            case .unknown:
                return outcome.withUnknownNetworkFee()
            }
        case let .executed(.failure(inner), _):
            throw dispatchFailure(for: inner)
        case let .notExecuted(carrier):
            let stage: SubtensorSubmissionFailure.Stage = carrier.map {
                .dispatched(blockHash: $0.blockHash, extrinsicHash: $0.extrinsicHash)
            } ?? .notSubmitted

            throw SubtensorSubmissionFailure(stage: stage, error: SubtensorSubmissionError.shieldedNotExecuted)
        case let .carrierFailed(carrier):
            throw dispatchFailure(for: carrier)
        }
    }
}

private extension SubtensorSubmissionFinalizer {
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

    func carrierFee(
        of carrier: SubstrateExtrinsicStatus.SuccessExtrinsic,
        operation: SubtensorOperation,
        codingFactory: RuntimeCoderFactoryProtocol?
    ) -> Balance? {
        guard let codingFactory else {
            return nil
        }

        let parser = SubtensorOutcomeParser(
            coldkey: accountId,
            novaFeeBeneficiary: novaFeeBeneficiary,
            codingFactory: codingFactory
        )

        return parser.parse(
            events: carrier.interestedEvents,
            for: operation,
            extrinsicHash: carrier.extrinsicHash,
            blockHash: carrier.blockHash
        ).networkFeePaid
    }
}

private extension SubtensorOperationOutcome {
    func withUnknownNetworkFee() -> SubtensorOperationOutcome {
        SubtensorOperationOutcome(
            executed: executed,
            novaFeePaid: novaFeePaid,
            alphaFeePaid: alphaFeePaid,
            networkFeePaid: nil,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )
    }

    func addingNetworkFee(_ fee: Balance?) -> SubtensorOperationOutcome {
        guard let fee else {
            return self
        }

        return SubtensorOperationOutcome(
            executed: executed,
            novaFeePaid: novaFeePaid,
            alphaFeePaid: alphaFeePaid,
            networkFeePaid: (networkFeePaid ?? 0) + fee,
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )
    }
}
