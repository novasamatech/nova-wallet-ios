import Foundation
import Operation_iOS
import SubstrateSdk

extension SubtensorSubmissionOperationFactory {
    func createShieldSigners(
        for operation: SubtensorOperation,
        signedClosure: @escaping () -> Void
    ) -> SubtensorShieldSigners? {
        guard
            let shield,
            SubtensorShieldEligibility.supports(operation: operation),
            let signer = shield.submissionFactory.createSigner() else {
            return nil
        }

        return SubtensorShieldSigners(
            inner: SubtensorRecordingSigner(signer: signer, signedClosure: signedClosure),
            carrier: SubtensorRecordingSigner(signer: signer, signedClosure: signedClosure)
        )
    }

    func createShieldedSubmissionWrapper(
        for operation: SubtensorOperation,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        signers: SubtensorShieldSigners,
        finalizer: SubtensorSubmissionFinalizer,
        submissionFactory: SubtensorShieldSubmissionFactoryProtocol
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        let submissionWrapper = submissionFactory.createSubmissionWrapper(
            for: builderClosure,
            signers: signers,
            matchingEvents: SubtensorEventMatcher()
        )

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let outcomeOperation = ClosureOperation<SubtensorOperationOutcome> {
            let submission: SubtensorShieldedSubmission

            do {
                submission = try submissionWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                throw finalizer.shieldedFailure(for: error)
            }

            let codingFactory = try? codingFactoryOperation.extractNoCancellableResultData()

            return try finalizer.shieldedOutcome(for: submission, operation: operation, codingFactory: codingFactory)
        }

        outcomeOperation.addDependency(submissionWrapper.targetOperation)
        outcomeOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: outcomeOperation,
            dependencies: submissionWrapper.allOperations + [codingFactoryOperation]
        )
    }
}

extension SubtensorSubmissionFinalizer {
    func shieldedFailure(for error: Error) -> SubtensorSubmissionFailure {
        guard error is FinalExtrinsicStatusError || error is SubtensorShieldError else {
            return failure(for: error)
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

            return outcome.addingNetworkFee(
                carrierFee(of: carrier, operation: operation, codingFactory: codingFactory)
            )
        case let .executed(.failure(inner), _):
            throw dispatchFailure(for: inner)
        case let .notExecuted(carrier):
            throw SubtensorSubmissionFailure(
                stage: .dispatched(blockHash: carrier.blockHash, extrinsicHash: carrier.extrinsicHash),
                error: SubtensorSubmissionError.shieldedNotExecuted
            )
        case let .carrierFailed(carrier):
            throw dispatchFailure(for: carrier)
        }
    }
}

private extension SubtensorSubmissionFinalizer {
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
