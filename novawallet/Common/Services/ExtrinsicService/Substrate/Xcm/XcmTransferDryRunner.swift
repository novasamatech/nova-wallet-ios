import Foundation
import Operation_iOS

struct XcmTransferDryRunParams {
    let callOrigin: RuntimeCallOrigin
    let call: AnyRuntimeCall
    let amountToSend: Balance
}

protocol XcmTransferDryRunning {
    func createDryRunWrapper(
        for request: XcmUnweightedTransferRequest,
        paramsClosure: @escaping () throws -> XcmTransferDryRunParams
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol>
}

enum XcmTransferDryRunnerError: Error {
    case emptyForwardedMessages
    case noForwardedMessage
    case noDepositFound
}

final class XcmTransferDryRunner {
    struct IntermediateResult {
        let forwardedXcm: XcmUni.VersionedMessage
        let deliveryFee: Balance
    }

    static let dryRunXcmVersion: Xcm.Version = .V4

    let chainRegistry: ChainRegistryProtocol
    let dryRunOperationFactory: DryRunOperationFactoryProtocol
    let palletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        dryRunOperationFactory: DryRunOperationFactoryProtocol,
        palletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.dryRunOperationFactory = dryRunOperationFactory
        self.palletMetadataQueryFactory = palletMetadataQueryFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension XcmTransferDryRunner {
    func createOriginIntermediateResult(
        for request: XcmUnweightedTransferRequest,
        dryRunResult: DryRun.CallResult,
        palletName: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> IntermediateResult {
        let effects = try dryRunResult.ensureSuccessExecution()

        let deliveryFee = XcmDeliveryFeeMatcher(
            palletName: palletName,
            logger: logger
        ).matchEventList(
            effects.emittedEvents,
            using: codingFactory
        )

        guard let xcmVersion = effects.forwardedXcms.first?.location.version else {
            throw XcmTransferDryRunnerError.emptyForwardedMessages
        }

        let messageOrigin = XcmUni.AbsoluteLocation(
            paraId: request.paraIdAfterOrigin
        )
        .fromChainPointOfView(request.origin.parachainId)
        .versioned(xcmVersion)

        guard
            let forwardedMessage = XcmForwardedMessageByLocationMatcher().matchFromForwardedXcms(
                effects.forwardedXcms,
                from: messageOrigin
            ) else {
            throw XcmTransferDryRunnerError.noForwardedMessage
        }

        return IntermediateResult(forwardedXcm: forwardedMessage, deliveryFee: deliveryFee ?? 0)
    }

    func dryRunOnOriginWrapper(
        for request: XcmUnweightedTransferRequest,
        paramsClosure: @escaping () throws -> XcmTransferDryRunParams
    ) -> CompoundOperationWrapper<IntermediateResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let params = try paramsClosure()
            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(for: request.originChain.chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
            let palletResolutionWrapper = self.palletMetadataQueryFactory.createModuleNameResolutionWrapper(
                for: runtimeProvider
            )

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunCallWrapper(
                params.call,
                origin: params.callOrigin,
                xcmVersion: Self.dryRunXcmVersion,
                chainId: request.originChain.chainId
            )

            let resultOperation = ClosureOperation<IntermediateResult> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let palletName = try palletResolutionWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                return try self.createOriginIntermediateResult(
                    for: request,
                    dryRunResult: dryRunResult,
                    palletName: palletName,
                    codingFactory: codingFactory
                )
            }

            resultOperation.addDependency(codingFactoryOperation)
            resultOperation.addDependency(palletResolutionWrapper.targetOperation)
            resultOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper
                .insertingHead(operations: palletResolutionWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: resultOperation)
        }
    }

    func createReserveIntermediateResult(
        for request: XcmUnweightedTransferRequest,
        originResult: IntermediateResult,
        dryRunResult: DryRun.XcmResult
    ) throws -> IntermediateResult {
        let effects = try dryRunResult.ensureSuccessExecution()

        guard let xcmVersion = effects.forwardedXcms.first?.location.version else {
            throw XcmTransferDryRunnerError.emptyForwardedMessages
        }

        let messageOrigin = XcmUni.AbsoluteLocation(
            paraId: request.destination.parachainId
        )
        .fromChainPointOfView(request.reserve.parachainId)
        .versioned(xcmVersion)

        guard
            let forwardedMessage = XcmForwardedMessageByLocationMatcher().matchFromForwardedXcms(
                effects.forwardedXcms,
                from: messageOrigin
            ) else {
            throw XcmTransferDryRunnerError.noForwardedMessage
        }

        return IntermediateResult(forwardedXcm: forwardedMessage, deliveryFee: originResult.deliveryFee)
    }

    func dryRunReserveWrapper(
        for request: XcmUnweightedTransferRequest,
        dependingOn originResult: BaseOperation<IntermediateResult>
    ) -> CompoundOperationWrapper<IntermediateResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let intermediateResult = try originResult.extractNoCancellableResultData()

            guard request.isNonReserveTransfer else {
                return .createWithResult(intermediateResult)
            }

            let xcmVersion = intermediateResult.forwardedXcm.version
            let location = XcmUni.AbsoluteLocation(
                paraId: request.origin.parachainId
            )
            .fromChainPointOfView(request.reserve.parachainId)
            .versioned(xcmVersion)

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunXcmWrapper(
                from: location,
                xcm: intermediateResult.forwardedXcm,
                chainId: request.reserveChain.chainId
            )

            let resultOperation = ClosureOperation<IntermediateResult> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()

                return try self.createReserveIntermediateResult(
                    for: request,
                    originResult: intermediateResult,
                    dryRunResult: dryRunResult
                )
            }

            resultOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper.insertingTail(operation: resultOperation)
        }
    }

    func createDestinationResult(
        for request: XcmUnweightedTransferRequest,
        params: XcmTransferDryRunParams,
        reserveResult: IntermediateResult,
        dryRunResult: DryRun.XcmResult,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> XcmFeeModelProtocol {
        let effects = try dryRunResult.ensureSuccessExecution()

        let depositEven = XcmTokensArrivalDetector(
            chainAsset: request.destination.chainAsset,
            logger: logger
        )?.searchDepositInEvents(
            effects.emittedEvents,
            accountId: request.destination.accountId,
            codingFactory: codingFactory
        )

        guard let depositEven else {
            throw XcmTransferDryRunnerError.noDepositFound
        }

        let totalFee = params.amountToSend.subtractOrZero(depositEven.amount)

        let feeModel = XcmFeeModel(
            senderPart: reserveResult.deliveryFee,
            holdingPart: totalFee
        )

        return feeModel
    }

    func dryRunDestinationWrapper(
        for request: XcmUnweightedTransferRequest,
        paramsClosure: @escaping () throws -> XcmTransferDryRunParams,
        dependingOn prevResult: BaseOperation<IntermediateResult>
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let intermediateResult = try prevResult.extractNoCancellableResultData()
            let params = try paramsClosure()

            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(
                for: request.destinationChain.chainId
            )

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let xcmVersion = intermediateResult.forwardedXcm.version

            let location = XcmUni.AbsoluteLocation(
                paraId: request.paraIdBeforeDestination
            )
            .fromChainPointOfView(request.destination.parachainId)
            .versioned(xcmVersion)

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunXcmWrapper(
                from: location,
                xcm: intermediateResult.forwardedXcm,
                chainId: request.destinationChain.chainId
            )

            let resultOperation = ClosureOperation<XcmFeeModelProtocol> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                return try self.createDestinationResult(
                    for: request,
                    params: params,
                    reserveResult: intermediateResult,
                    dryRunResult: dryRunResult,
                    codingFactory: codingFactory
                )
            }

            resultOperation.addDependency(codingFactoryOperation)
            resultOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: resultOperation)
        }
    }
}

extension XcmTransferDryRunner: XcmTransferDryRunning {
    func createDryRunWrapper(
        for request: XcmUnweightedTransferRequest,
        paramsClosure: @escaping () throws -> XcmTransferDryRunParams
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let originDryRunWrapper = dryRunOnOriginWrapper(
            for: request,
            paramsClosure: paramsClosure
        )

        let reserveDryRunWrapper = dryRunReserveWrapper(
            for: request,
            dependingOn: originDryRunWrapper.targetOperation
        )

        reserveDryRunWrapper.addDependency(wrapper: originDryRunWrapper)

        let destinationDryRunWrapper = dryRunDestinationWrapper(
            for: request,
            paramsClosure: paramsClosure,
            dependingOn: reserveDryRunWrapper.targetOperation
        )

        destinationDryRunWrapper.addDependency(wrapper: reserveDryRunWrapper)

        return destinationDryRunWrapper
            .insertingHead(operations: reserveDryRunWrapper.allOperations)
            .insertingHead(operations: originDryRunWrapper.allOperations)
    }
}
