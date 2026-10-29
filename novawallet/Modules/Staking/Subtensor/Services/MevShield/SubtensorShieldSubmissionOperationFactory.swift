import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorShieldSubmissionOperationFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        blockTiming: SubtensorShieldBlockTiming,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote>

    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createSigner() -> SigningWrapperProtocol?

    func createSubmissionWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signers: SubtensorShieldSigners,
        blockTiming: SubtensorShieldBlockTiming,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission>
}

struct SubtensorShieldSigners {
    let inner: SigningWrapperProtocol
    let carrier: SubtensorRecordingSigner
    let authorizer: SigningPreauthorizing?
}

struct SubtensorShieldServices {
    let submissionOperationFactory: SubtensorShieldSubmissionOperationFactoryProtocol
    let operationQueue: OperationQueue
}

final class SubtensorShieldSubmissionOperationFactory {
    let walletType: MetaAccountModelType
    let extrinsicOperationFactory: SubtensorShieldExtrinsicOperationFactoryProtocol
    let fundsOperationFactory: SubtensorShieldFundsOperationFactoryProtocol
    let carrierWatch: SubtensorShieldCarrierWatchingProtocol
    let inclusionOperationFactory: SubtensorShieldInclusionOperationFactoryProtocol
    let signerFactory: () -> SigningWrapperProtocol?
    let operationQueue: OperationQueue

    init(
        walletType: MetaAccountModelType,
        extrinsicOperationFactory: SubtensorShieldExtrinsicOperationFactoryProtocol,
        fundsOperationFactory: SubtensorShieldFundsOperationFactoryProtocol,
        carrierWatch: SubtensorShieldCarrierWatchingProtocol,
        inclusionOperationFactory: SubtensorShieldInclusionOperationFactoryProtocol,
        signerFactory: @escaping () -> SigningWrapperProtocol?,
        operationQueue: OperationQueue
    ) {
        self.walletType = walletType
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.fundsOperationFactory = fundsOperationFactory
        self.carrierWatch = carrierWatch
        self.inclusionOperationFactory = inclusionOperationFactory
        self.signerFactory = signerFactory
        self.operationQueue = operationQueue
    }
}

private extension SubtensorShieldSubmissionOperationFactory {
    func createWatchWrapper(
        carrierWrapper: CompoundOperationWrapper<ExtrinsicBuiltModel>
    ) -> CompoundOperationWrapper<SubtensorShieldCarrierWatchResult> {
        OperationCombiningService<SubtensorShieldCarrierWatchResult>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let carrier = try carrierWrapper.targetOperation.extractNoCancellableResultData()

            let watchOperation = self.carrierWatch.createWatchOperation(for: try Data(hexString: carrier.extrinsic))

            return CompoundOperationWrapper(targetOperation: watchOperation)
        }
    }

    func createScannedResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: ExtrinsicBuiltModel,
        rejection: Error?,
        blockTiming: SubtensorShieldBlockTiming,
        matchingEvents: ExtrinsicEventsMatching?
    ) throws -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let scanWrapper = inclusionOperationFactory.createInnerScanWrapper(
            for: sealedInner.extrinsicHash,
            carrierHash: try Data(hexString: carrier.extrinsic).blake2b32().toHex(includePrefix: true),
            eraBirth: sealedInner.era.blockNumber,
            blockTiming: blockTiming,
            matchingEvents: matchingEvents
        )

        let resolutionOperation = ClosureOperation<SubtensorShieldedSubmission> {
            switch try scanWrapper.targetOperation.extractNoCancellableResultData() {
            case let .found(inner, carrierLookup):
                .executed(inner: inner, carrier: carrierLookup)
            case let .absent(carrierLookup):
                .notExecuted(carrier: carrierLookup, rejection: rejection)
            }
        }

        resolutionOperation.addDependency(scanWrapper.targetOperation)

        return scanWrapper.insertingTail(operation: resolutionOperation)
    }
}

extension SubtensorShieldSubmissionOperationFactory: SubtensorShieldSubmissionOperationFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        blockTiming: SubtensorShieldBlockTiming,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote> {
        let quoteWrapper = extrinsicOperationFactory.createQuoteWrapper(
            for: operation,
            requiresKey: false
        ) { innerClosure }
        let fundsWrapper = fundsOperationFactory.createFundsWrapper()

        let eligibilityOperation = ClosureOperation<Bool> { [walletType] in
            let funds = try fundsWrapper.targetOperation.extractNoCancellableResultData()

            let input = SubtensorShieldEligibilityInput(
                walletType: walletType,
                quote: try quoteWrapper.targetOperation.extractNoCancellableResultData(),
                transferable: funds.transferable,
                existentialDeposit: funds.existentialDeposit
            )

            return SubtensorShieldEligibility.isEligible(input)
        }

        eligibilityOperation.addDependency(quoteWrapper.targetOperation)
        eligibilityOperation.addDependency(fundsWrapper.targetOperation)

        let keyWrapper = extrinsicOperationFactory.createKeyWrapper(
            blockTiming: blockTiming,
            retryCondition: eligibilityOperation
        )

        let readinessOperation = ClosureOperation<SubtensorShieldQuote> {
            let key = try keyWrapper.targetOperation.extractNoCancellableResultData()

            guard let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData() else {
                throw SubtensorShieldError.quoteUnavailable
            }

            guard try eligibilityOperation.extractNoCancellableResultData() else {
                throw SubtensorShieldError.fundsShort
            }

            guard key != nil else {
                throw SubtensorShieldError.keyUnavailable
            }

            return quote
        }

        readinessOperation.addDependency(quoteWrapper.targetOperation)
        readinessOperation.addDependency(eligibilityOperation)
        readinessOperation.addDependency(keyWrapper.targetOperation)

        let headOperations = quoteWrapper.allOperations + fundsWrapper.allOperations + [eligibilityOperation]

        return keyWrapper
            .insertingHead(operations: headOperations)
            .insertingTail(operation: readinessOperation)
    }

    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        extrinsicOperationFactory.createQuoteWrapper(for: operation, requiresKey: true, innerClosure: innerClosure)
    }

    func createSigner() -> SigningWrapperProtocol? {
        signerFactory()
    }

    func createSubmissionWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signers: SubtensorShieldSigners,
        blockTiming: SubtensorShieldBlockTiming,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let sealedWrapper = extrinsicOperationFactory.createSealedInnerWrapper(
            for: innerClosure,
            signer: signers.inner,
            authorization: { try signers.authorizer?.preauthorize() }
        )

        let carrierWrapper = OperationCombiningService<ExtrinsicBuiltModel>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let sealedInner = try sealedWrapper.targetOperation.extractNoCancellableResultData()

            return self.extrinsicOperationFactory.createCarrierWrapper(for: sealedInner, signer: signers.carrier)
        }

        carrierWrapper.addDependency(wrapper: sealedWrapper)

        let watchWrapper = createWatchWrapper(carrierWrapper: carrierWrapper)
        watchWrapper.addDependency(wrapper: carrierWrapper)

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let sealedInner = try sealedWrapper.targetOperation.extractNoCancellableResultData()
            let carrier = try carrierWrapper.targetOperation.extractNoCancellableResultData()
            let watchResult = try watchWrapper.targetOperation.extractNoCancellableResultData()

            // a submit re-sent after a reconnect can be refused by a node that never held the first copy,
            // so only the finalized era scan settles the outcome; the rejection just picks the copy
            let rejection: Error? = if case let .rejected(error) = watchResult { error } else { nil }

            return try self.createScannedResolutionWrapper(
                for: sealedInner,
                carrier: carrier,
                rejection: rejection,
                blockTiming: blockTiming,
                matchingEvents: matchingEvents
            )
        }

        resolutionWrapper.addDependency(wrapper: watchWrapper)

        let headOperations = sealedWrapper.allOperations + carrierWrapper.allOperations +
            watchWrapper.allOperations

        return resolutionWrapper.insertingHead(operations: headOperations)
    }
}
