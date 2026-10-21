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
            inner: SubtensorRecordingSigner(signer: signer) {},
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
