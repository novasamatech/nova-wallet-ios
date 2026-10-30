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
            let signer = shield.submissionOperationFactory.createSigner() else {
            return nil
        }

        return SubtensorShieldSigners(
            inner: signer,
            carrier: SubtensorRecordingSigner(signer: signer, signedClosure: signedClosure),
            authorizer: signer as? SigningPreauthorizing
        )
    }

    func createShieldedOutcomeWrapper(
        for operation: SubtensorOperation,
        submissionWrapper: CompoundOperationWrapper<SubtensorShieldedSubmission>,
        quote: SubtensorShieldQuote,
        finalizer: SubtensorSubmissionFinalizer
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let outcomeOperation = ClosureOperation<SubtensorOperationOutcome> { [logger] in
            let submission: SubtensorShieldedSubmission

            do {
                submission = try submissionWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Shielded submission failed: \(error)")
                throw finalizer.shieldedFailure(for: error)
            }

            let codingFactory = try? codingFactoryOperation.extractNoCancellableResultData()

            return try finalizer.shieldedOutcome(
                for: submission,
                operation: operation,
                quote: quote,
                codingFactory: codingFactory
            )
        }

        outcomeOperation.addDependency(submissionWrapper.targetOperation)
        outcomeOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: outcomeOperation,
            dependencies: submissionWrapper.allOperations + [codingFactoryOperation]
        )
    }
}
