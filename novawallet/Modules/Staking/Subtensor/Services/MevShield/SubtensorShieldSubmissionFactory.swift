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
    let carrierWatch: SubtensorShieldCarrierWatchingProtocol
    let inclusionTracker: SubtensorShieldInclusionTrackingProtocol
    let statusService: ExtrinsicStatusServiceProtocol
    let signerFactory: () -> SigningWrapperProtocol?
    let operationQueue: OperationQueue

    init(
        walletType: MetaAccountModelType,
        extrinsicFactory: SubtensorShieldExtrinsicFactoryProtocol,
        fundsFactory: SubtensorShieldFundsFactoryProtocol,
        carrierWatch: SubtensorShieldCarrierWatchingProtocol,
        inclusionTracker: SubtensorShieldInclusionTrackingProtocol,
        statusService: ExtrinsicStatusServiceProtocol,
        signerFactory: @escaping () -> SigningWrapperProtocol?,
        operationQueue: OperationQueue
    ) {
        self.walletType = walletType
        self.extrinsicFactory = extrinsicFactory
        self.fundsFactory = fundsFactory
        self.carrierWatch = carrierWatch
        self.inclusionTracker = inclusionTracker
        self.statusService = statusService
        self.signerFactory = signerFactory
        self.operationQueue = operationQueue
    }
}

private extension SubtensorShieldSubmissionFactory {
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

    static func blockHash(of status: SubstrateExtrinsicStatus) -> BlockHash {
        switch status {
        case let .success(success):
            success.blockHash
        case let .failure(failure):
            failure.blockHash
        }
    }

    func createCarrierStatusWrapper(
        for carrier: ExtrinsicBuiltModel,
        inBlock blockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?
    ) throws -> CompoundOperationWrapper<SubstrateExtrinsicStatus> {
        let carrierHash = try Data(hexString: carrier.extrinsic).blake2b32().toHex(includePrefix: true)

        return statusService.fetchExtrinsicStatusForHash(
            carrierHash,
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )
    }

    func createScannedCarrierWrapper(
        for inner: SubstrateExtrinsicStatus,
        carrier: ExtrinsicBuiltModel,
        matchingEvents: ExtrinsicEventsMatching?
    ) throws -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let carrierWrapper = try createCarrierStatusWrapper(
            for: carrier,
            inBlock: Self.blockHash(of: inner),
            matchingEvents: matchingEvents
        )

        let mapOperation = ClosureOperation<SubtensorShieldedSubmission> {
            guard case let .success(carrierSuccess)? = try? carrierWrapper.targetOperation
                .extractNoCancellableResultData() else {
                return .executed(inner: inner, carrier: nil)
            }

            return .executed(inner: inner, carrier: carrierSuccess)
        }

        mapOperation.addDependency(carrierWrapper.targetOperation)

        return carrierWrapper.insertingTail(operation: mapOperation)
    }

    func createScannedResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: ExtrinsicBuiltModel,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let statusWrapper = inclusionTracker.createInnerStatusWrapper(
            for: sealedInner.extrinsicHash,
            in: .innerEra(birth: sealedInner.era.blockNumber),
            matchingEvents: matchingEvents
        )

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            guard let inner = try statusWrapper.targetOperation.extractNoCancellableResultData() else {
                return .createWithResult(.notExecuted(carrier: nil))
            }

            return try self.createScannedCarrierWrapper(for: inner, carrier: carrier, matchingEvents: matchingEvents)
        }

        resolutionWrapper.addDependency(wrapper: statusWrapper)

        return resolutionWrapper.insertingHead(operations: statusWrapper.allOperations)
    }

    func createInnerResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: SubstrateExtrinsicStatus.SuccessExtrinsic,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let statusWrapper = inclusionTracker.createInnerStatusWrapper(
            for: sealedInner.extrinsicHash,
            in: .fromCarrierBlock(carrier.blockHash),
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

    func createRejectedResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: ExtrinsicBuiltModel,
        rejection: Error,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let nonceWrapper = extrinsicFactory.createNonceWrapper()

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let nextNonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            guard nextNonce > sealedInner.carrierNonce else {
                throw SubtensorShieldError.carrierRejected(rejection)
            }

            return self.createScannedResolutionWrapper(
                for: sealedInner,
                carrier: carrier,
                matchingEvents: matchingEvents
            )
        }

        resolutionWrapper.addDependency(wrapper: nonceWrapper)

        return resolutionWrapper.insertingHead(operations: nonceWrapper.allOperations)
    }

    func createIncludedResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: ExtrinsicBuiltModel,
        blockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?
    ) throws -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let statusWrapper = try createCarrierStatusWrapper(
            for: carrier,
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            switch try statusWrapper.targetOperation.extractNoCancellableResultData() {
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

        resolutionWrapper.addDependency(wrapper: statusWrapper)

        return resolutionWrapper.insertingHead(operations: statusWrapper.allOperations)
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

        let carrierWrapper = OperationCombiningService<ExtrinsicBuiltModel>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let sealedInner = try sealedWrapper.targetOperation.extractNoCancellableResultData()

            return self.extrinsicFactory.createCarrierWrapper(for: sealedInner, signer: signers.carrier)
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

            switch watchResult {
            case let .included(blockHash):
                return try self.createIncludedResolutionWrapper(
                    for: sealedInner,
                    carrier: carrier,
                    blockHash: blockHash,
                    matchingEvents: matchingEvents
                )
            case let .rejected(error):
                return self.createRejectedResolutionWrapper(
                    for: sealedInner,
                    carrier: carrier,
                    rejection: error,
                    matchingEvents: matchingEvents
                )
            case .lost:
                return self.createScannedResolutionWrapper(
                    for: sealedInner,
                    carrier: carrier,
                    matchingEvents: matchingEvents
                )
            }
        }

        resolutionWrapper.addDependency(wrapper: watchWrapper)

        let headOperations = sealedWrapper.allOperations + carrierWrapper.allOperations +
            watchWrapper.allOperations

        return resolutionWrapper.insertingHead(operations: headOperations)
    }
}
