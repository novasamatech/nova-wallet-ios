import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorShieldSubmissionFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<Bool>

    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createSigner() -> SigningWrapperProtocol?

    func createSubmissionWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signers: SubtensorShieldSigners,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission>
}

struct SubtensorShieldSigners {
    let inner: SubtensorRecordingSigner
    let carrier: SubtensorRecordingSigner
}

struct SubtensorShieldServices {
    let submissionFactory: SubtensorShieldSubmissionFactoryProtocol
    let operationQueue: OperationQueue
}

final class SubtensorShieldSubmissionFactory {
    let walletType: MetaAccountModelType
    let extrinsicFactory: SubtensorShieldExtrinsicFactoryProtocol
    let fundsFactory: SubtensorShieldFundsFactoryProtocol
    let inclusionTracker: SubtensorShieldInclusionTrackingProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let signerFactory: () -> SigningWrapperProtocol?
    let operationQueue: OperationQueue

    init(
        walletType: MetaAccountModelType,
        extrinsicFactory: SubtensorShieldExtrinsicFactoryProtocol,
        fundsFactory: SubtensorShieldFundsFactoryProtocol,
        inclusionTracker: SubtensorShieldInclusionTrackingProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        signerFactory: @escaping () -> SigningWrapperProtocol?,
        operationQueue: OperationQueue
    ) {
        self.walletType = walletType
        self.extrinsicFactory = extrinsicFactory
        self.fundsFactory = fundsFactory
        self.inclusionTracker = inclusionTracker
        self.statusService = statusService
        self.signerFactory = signerFactory
        self.operationQueue = operationQueue
    }
}

private extension SubtensorShieldSubmissionFactory {
    func createCarrierWrapper(
        for sealedInner: SubtensorSealedInner,
        signer: SigningWrapperProtocol,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        let monitor = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicFactory.createCarrierService(nonce: sealedInner.carrierNonce),
            statusService: statusService,
            operationQueue: operationQueue
        )

        return monitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: SubtensorShieldExtrinsicFactory.carrierClosure(ciphertext: sealedInner.ciphertext),
            payingIn: nil,
            signer: signer,
            matchingEvents: matchingEvents
        )
    }

    func createInnerResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: SubstrateExtrinsicStatus.SuccessExtrinsic,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let statusWrapper = inclusionTracker.createInnerStatusWrapper(
            for: sealedInner.extrinsicHash,
            carrierBlockHash: carrier.blockHash,
            matchingEvents: matchingEvents
        )

        let mapOperation = ClosureOperation<SubtensorShieldedSubmission> {
            guard let inner = try statusWrapper.targetOperation.extractNoCancellableResultData() else {
                return .notExecuted(carrier: carrier)
            }

            return .executed(inner: inner, carrier: carrier)
        }

        mapOperation.addDependency(statusWrapper.targetOperation)

        return statusWrapper.insertingTail(operation: mapOperation)
    }
}

extension SubtensorShieldSubmissionFactory: SubtensorShieldSubmissionFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<Bool> {
        let quoteWrapper = extrinsicFactory.createQuoteWrapper(for: operation) { innerClosure }
        let fundsWrapper = fundsFactory.createFundsWrapper()

        let readinessOperation = ClosureOperation<Bool> { [walletType] in
            let funds = try fundsWrapper.targetOperation.extractNoCancellableResultData()

            let input = SubtensorShieldEligibilityInput(
                walletType: walletType,
                quote: try quoteWrapper.targetOperation.extractNoCancellableResultData(),
                transferable: funds.transferable,
                existentialDeposit: funds.existentialDeposit
            )

            return SubtensorShieldEligibility.isEligible(input)
        }

        readinessOperation.addDependency(quoteWrapper.targetOperation)
        readinessOperation.addDependency(fundsWrapper.targetOperation)

        return quoteWrapper
            .insertingHead(operations: fundsWrapper.allOperations)
            .insertingTail(operation: readinessOperation)
    }

    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        extrinsicFactory.createQuoteWrapper(for: operation, innerClosure: innerClosure)
    }

    func createSigner() -> SigningWrapperProtocol? {
        signerFactory()
    }

    func createSubmissionWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signers: SubtensorShieldSigners,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let sealedWrapper = extrinsicFactory.createSealedInnerWrapper(for: innerClosure, signer: signers.inner)

        let carrierWrapper = OperationCombiningService<ExtrinsicMonitorSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let sealedInner = try sealedWrapper.targetOperation.extractNoCancellableResultData()

            return self.createCarrierWrapper(for: sealedInner, signer: signers.carrier, matchingEvents: matchingEvents)
        }

        carrierWrapper.addDependency(wrapper: sealedWrapper)

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let sealedInner = try sealedWrapper.targetOperation.extractNoCancellableResultData()
            let carrier = try carrierWrapper.targetOperation.extractNoCancellableResultData()

            switch carrier.status {
            case let .success(carrierSuccess):
                return self.createInnerResolutionWrapper(
                    for: sealedInner,
                    carrier: carrierSuccess,
                    matchingEvents: matchingEvents
                )
            case let .failure(carrierFailure):
                return .createWithResult(.carrierFailed(carrierFailure))
            }
        }

        resolutionWrapper.addDependency(wrapper: carrierWrapper)

        return resolutionWrapper.insertingHead(operations: sealedWrapper.allOperations + carrierWrapper.allOperations)
    }
}
