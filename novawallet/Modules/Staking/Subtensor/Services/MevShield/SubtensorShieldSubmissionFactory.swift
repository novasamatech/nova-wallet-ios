import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorShieldSubmissionFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        keyRetry: SubtensorShieldKeyRetry,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

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
    let authorizer: SigningPreauthorizing?
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
    enum Constants {
        static let carrierLookupRetries = 1
    }

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

    func createCarrierLookupWrapper(
        for carrier: ExtrinsicBuiltModel,
        inBlock blockHash: BlockHash,
        matchingEvents: ExtrinsicEventsMatching?,
        retries: Int
    ) throws -> CompoundOperationWrapper<SubtensorShieldCarrierLookup> {
        let statusWrapper = try createCarrierStatusWrapper(
            for: carrier,
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )

        let lookupWrapper = OperationCombiningService<SubtensorShieldCarrierLookup>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            do {
                switch try statusWrapper.targetOperation.extractNoCancellableResultData() {
                case let .success(carrierSuccess):
                    return .createWithResult(.found(carrierSuccess))
                case .failure:
                    return .createWithResult(.unknown)
                }
            } catch ExtrinsicStatusServiceError.extrinsicNotFound(_) {
                return .createWithResult(.absent)
            } catch {
                guard retries > 0 else {
                    return .createWithResult(.unknown)
                }

                return try self.createCarrierLookupWrapper(
                    for: carrier,
                    inBlock: blockHash,
                    matchingEvents: matchingEvents,
                    retries: retries - 1
                )
            }
        }

        lookupWrapper.addDependency(wrapper: statusWrapper)

        return lookupWrapper.insertingHead(operations: statusWrapper.allOperations)
    }

    func createCarrierScanWrapper(
        for carrier: ExtrinsicBuiltModel,
        in blocks: [BlockHash],
        matchingEvents: ExtrinsicEventsMatching?
    ) throws -> CompoundOperationWrapper<SubtensorShieldCarrierLookup> {
        let lookupWrappers = try blocks.map { blockHash in
            try createCarrierLookupWrapper(
                for: carrier,
                inBlock: blockHash,
                matchingEvents: matchingEvents,
                retries: Constants.carrierLookupRetries
            )
        }

        let combineOperation = ClosureOperation<SubtensorShieldCarrierLookup> {
            let lookups = try lookupWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            for lookup in lookups {
                if case .found = lookup {
                    return lookup
                }
            }

            return lookups.contains { if case .unknown = $0 { true } else { false } } ? .unknown : .absent
        }

        lookupWrappers.forEach { combineOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: combineOperation,
            dependencies: lookupWrappers.flatMap(\.allOperations)
        )
    }

    func createScannedResolutionWrapper(
        for sealedInner: SubtensorSealedInner,
        carrier: ExtrinsicBuiltModel,
        matchingEvents: ExtrinsicEventsMatching?
    ) -> CompoundOperationWrapper<SubtensorShieldedSubmission> {
        let scanWrapper = inclusionTracker.createInnerScanWrapper(
            for: sealedInner.extrinsicHash,
            eraBirth: sealedInner.era.blockNumber,
            matchingEvents: matchingEvents
        )

        let resolutionWrapper = OperationCombiningService<SubtensorShieldedSubmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let scan = try scanWrapper.targetOperation.extractNoCancellableResultData()

            let blocks: [BlockHash] = switch scan {
            case let .found(inner):
                [Self.blockHash(of: inner)]
            case let .absent(scannedBlocks):
                scannedBlocks
            }

            let lookupWrapper = try self.createCarrierScanWrapper(
                for: carrier,
                in: blocks,
                matchingEvents: matchingEvents
            )

            let mapOperation = ClosureOperation<SubtensorShieldedSubmission> {
                let lookup = try lookupWrapper.targetOperation.extractNoCancellableResultData()

                switch scan {
                case let .found(inner):
                    return .executed(inner: inner, carrier: lookup)
                case .absent:
                    return .notExecuted(carrier: lookup)
                }
            }

            mapOperation.addDependency(lookupWrapper.targetOperation)

            return lookupWrapper.insertingTail(operation: mapOperation)
        }

        resolutionWrapper.addDependency(wrapper: scanWrapper)

        return resolutionWrapper.insertingHead(operations: scanWrapper.allOperations)
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
}

extension SubtensorShieldSubmissionFactory: SubtensorShieldSubmissionFactoryProtocol {
    func createReadinessWrapper(
        for operation: SubtensorOperation,
        keyRetry: SubtensorShieldKeyRetry,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        let quoteWrapper = extrinsicFactory.createQuoteWrapper(for: operation, keyRetry: keyRetry) { innerClosure }
        let fundsWrapper = fundsFactory.createFundsWrapper()

        let readinessOperation = ClosureOperation<SubtensorShieldQuote?> { [walletType] in
            let funds = try fundsWrapper.targetOperation.extractNoCancellableResultData()
            let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()

            let input = SubtensorShieldEligibilityInput(
                walletType: walletType,
                quote: quote,
                transferable: funds.transferable,
                existentialDeposit: funds.existentialDeposit
            )

            return SubtensorShieldEligibility.isEligible(input) ? quote : nil
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
        let sealedWrapper = extrinsicFactory.createSealedInnerWrapper(
            for: innerClosure,
            signer: signers.inner,
            authorization: { try signers.authorizer?.preauthorize() }
        )

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
            case .included, .lost:
                return self.createScannedResolutionWrapper(
                    for: sealedInner,
                    carrier: carrier,
                    matchingEvents: matchingEvents
                )
            case let .rejected(error):
                return self.createRejectedResolutionWrapper(
                    for: sealedInner,
                    carrier: carrier,
                    rejection: error,
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
