import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum XcmDynamicCrosschainFeeCalculatorError: Error {
    case emptyForwardedMessages
    case noForwardedMessage
    case noDepositFound
}

final class XcmDynamicCrosschainFeeCalculator {
    struct InitialModel {
        let call: AnyRuntimeCall
        let sender: AccountId
        let amountToSend: Balance
    }

    struct IntermediateResult {
        let forwardedXcm: Xcm.Message
        let deliveryFee: BigUInt
    }

    static let maxWeight = BigUInt(UInt64.max) // TODO: Move to enum
    static let minimumSendAmount: Decimal = 100
    static let minimumFundAmount: Decimal = minimumSendAmount * 2

    let chainRegistry: ChainRegistryProtocol
    let dryRunOperationFactory: DryRunOperationFactoryProtocol
    let callDerivator: XcmCallDerivating
    let palletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol
    let tokenMintingFactory: TokenBalanceMintingFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry

        dryRunOperationFactory = DryRunOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        callDerivator = XcmCallDerivator(chainRegistry: chainRegistry)

        palletMetadataQueryFactory = XcmPalletMetadataQueryFactory()
        tokenMintingFactory = TokenBalanceMintingFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension XcmDynamicCrosschainFeeCalculator {
    func ensureSafeAmountToSend(for request: XcmUnweightedTransferRequest) -> XcmUnweightedTransferRequest {
        let minimumAmount = Self.minimumSendAmount.toSubstrateAmount(
            precision: request.origin.chainAsset.assetDisplayInfo.assetPrecision
        )

        let safeAmount = max(minimumAmount ?? request.amount, request.amount)

        return request.replacing(amount: safeAmount)
    }

    func ensureSafeAmountToFund(for sendAmount: Balance?, chainAsset: ChainAsset) -> Balance {
        let minimumAmount = Self.minimumFundAmount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )

        guard let sendAmount else {
            return minimumAmount ?? 0
        }

        return max(2 * sendAmount, minimumAmount ?? 2 * sendAmount)
    }

    func createCallWrapper(
        for request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<InitialModel> {
        do {
            let xcmDerivationWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: request,
                maxWeight: Self.maxWeight
            )

            let senderAccount = try request.originChain.emptyAccountId()

            let amountToFund = ensureSafeAmountToFund(
                for: request.amount,
                chainAsset: request.origin.chainAsset
            )

            let targetTokenMintWrapper = tokenMintingFactory.createTokenMintingWrapper(
                for: senderAccount,
                amount: amountToFund,
                chainAsset: request.origin.chainAsset
            )

            let nativeTokenMintWrapper: CompoundOperationWrapper<RuntimeCallCollecting>?

            if
                !request.origin.chainAsset.isUtilityAsset,
                let nativeAsset = request.originChain.utilityChainAsset() {
                let nativeAmountToFund = ensureSafeAmountToFund(for: nil, chainAsset: nativeAsset)

                nativeTokenMintWrapper = tokenMintingFactory.createTokenMintingWrapper(
                    for: senderAccount,
                    amount: nativeAmountToFund,
                    chainAsset: nativeAsset
                )
            } else {
                nativeTokenMintWrapper = nil
            }

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: request.originChain.chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let callBuilderOperation = ClosureOperation<InitialModel> {
                let xcmCallCollector = try xcmDerivationWrapper.targetOperation.extractNoCancellableResultData()
                let targetMintCollector = try targetTokenMintWrapper.targetOperation.extractNoCancellableResultData()
                let nativeMintCollector = try nativeTokenMintWrapper?.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                var callBuilder: RuntimeCallBuilding = RuntimeCallBuilder(
                    context: codingFactory.createRuntimeJsonContext()
                )

                callBuilder = try xcmCallCollector
                    .addingToCall(builder: callBuilder, toEnd: true)
                    .dispatchingAs(.system(.signed(senderAccount)))

                callBuilder = try targetMintCollector.addingToCall(
                    builder: callBuilder,
                    toEnd: false
                )

                if let nativeMintCollector {
                    callBuilder = try nativeMintCollector.addingToCall(
                        builder: callBuilder,
                        toEnd: false
                    )
                }

                let call = try callBuilder
                    .batching(.batchAll)
                    .build()

                return InitialModel(
                    call: call,
                    sender: senderAccount,
                    amountToSend: request.amount
                )
            }

            callBuilderOperation.addDependency(codingFactoryOperation)
            callBuilderOperation.addDependency(targetTokenMintWrapper.targetOperation)
            callBuilderOperation.addDependency(xcmDerivationWrapper.targetOperation)

            if let nativeTokenMintWrapper {
                callBuilderOperation.addDependency(nativeTokenMintWrapper.targetOperation)
                return xcmDerivationWrapper
                    .insertingHead(operations: targetTokenMintWrapper.allOperations)
                    .insertingHead(operations: nativeTokenMintWrapper.allOperations)
                    .insertingHead(operations: [codingFactoryOperation])
                    .insertingTail(operation: callBuilderOperation)
            } else {
                return xcmDerivationWrapper
                    .insertingHead(operations: targetTokenMintWrapper.allOperations)
                    .insertingHead(operations: [codingFactoryOperation])
                    .insertingTail(operation: callBuilderOperation)
            }

        } catch {
            return .createWithError(error)
        }
    }

    func dryRunOnOriginWrapper(
        for request: XcmUnweightedTransferRequest,
        dependingOn initialOperation: BaseOperation<InitialModel>
    ) -> CompoundOperationWrapper<IntermediateResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let call = try initialOperation.extractNoCancellableResultData().call
            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(for: request.originChain.chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
            let palletResolutionWrapper = self.palletMetadataQueryFactory.createModuleNameResolutionWrapper(
                for: runtimeProvider
            )

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunCallWrapper(
                call,
                origin: .system(.root),
                chainId: request.originChain.chainId
            )

            let resultOperation = ClosureOperation<IntermediateResult> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let effects = try dryRunResult.ensureSuccessExecution()
                let palletName = try palletResolutionWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let deliveryFee = XcmDeliveryFeeMatcher(
                    palletName: palletName,
                    logger: self.logger
                ).matchEventList(
                    effects.emittedEvents,
                    using: codingFactory
                )

                guard let xcmVersion = effects.forwardedXcms.first?.location.version else {
                    throw XcmDynamicCrosschainFeeCalculatorError.emptyForwardedMessages
                }

                let forwardedMessage = try XcmForwardedMessageMatcher(
                    palletName: palletName,
                    logger: self.logger
                ).matchMessage(
                    from: effects.emittedEvents,
                    forwardedXcms: effects.forwardedXcms,
                    origin: .location(
                        for: request.nextChainAfterOrigin,
                        parachainId: request.nextParaIdAfterOrigin,
                        relativeTo: request.originChain,
                        version: xcmVersion
                    ),
                    codingFactory: codingFactory
                )

                guard let forwardedMessage else {
                    throw XcmDynamicCrosschainFeeCalculatorError.noForwardedMessage
                }

                return IntermediateResult(forwardedXcm: forwardedMessage, deliveryFee: deliveryFee ?? 0)
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

    func dryRunReserveWrapper(
        for request: XcmUnweightedTransferRequest,
        dependingOn originResult: BaseOperation<IntermediateResult>
    ) -> CompoundOperationWrapper<IntermediateResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let intermediateResult = try originResult.extractNoCancellableResultData()

            guard request.isNonReserveTransfer else {
                return .createWithResult(intermediateResult)
            }

            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(for: request.reserveChain.chainId)
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
            let palletResolutionWrapper = self.palletMetadataQueryFactory.createModuleNameResolutionWrapper(
                for: runtimeProvider
            )

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunXcmWrapper(
                from: .location(
                    for: request.originChain,
                    parachainId: request.origin.parachainId,
                    relativeTo: request.reserveChain,
                    version: intermediateResult.forwardedXcm.version
                ),
                xcm: intermediateResult.forwardedXcm,
                chainId: request.reserveChain.chainId
            )

            let resultOperation = ClosureOperation<IntermediateResult> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let effects = try dryRunResult.ensureSuccessExecution()
                let palletName = try palletResolutionWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                guard let xcmVersion = effects.forwardedXcms.first?.location.version else {
                    throw XcmDynamicCrosschainFeeCalculatorError.emptyForwardedMessages
                }

                let forwardedMessage = try XcmForwardedMessageMatcher(
                    palletName: palletName,
                    logger: self.logger
                ).matchMessage(
                    from: effects.emittedEvents,
                    forwardedXcms: effects.forwardedXcms,
                    origin: .location(
                        for: request.destinationChain,
                        parachainId: request.destination.parachainId,
                        relativeTo: request.reserveChain,
                        version: xcmVersion
                    ),
                    codingFactory: codingFactory
                )

                guard let forwardedMessage else {
                    throw XcmDynamicCrosschainFeeCalculatorError.noForwardedMessage
                }

                return IntermediateResult(forwardedXcm: forwardedMessage, deliveryFee: intermediateResult.deliveryFee)
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

    func dryRunDestinationWrapper(
        for request: XcmUnweightedTransferRequest,
        dependingOn prevResult: BaseOperation<IntermediateResult>,
        initialOperation: BaseOperation<InitialModel>
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let intermediateResult = try prevResult.extractNoCancellableResultData()
            let initialModel = try initialOperation.extractNoCancellableResultData()

            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(
                for: request.destinationChain.chainId
            )

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunXcmWrapper(
                from: .location(
                    for: request.chainBeforeDestination,
                    parachainId: request.paraIdBeforeDestination,
                    relativeTo: request.destinationChain,
                    version: intermediateResult.forwardedXcm.version
                ),
                xcm: intermediateResult.forwardedXcm,
                chainId: request.destinationChain.chainId
            )

            let resultOperation = ClosureOperation<XcmFeeModelProtocol> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let effects = try dryRunResult.ensureSuccessExecution()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let depositEven = XcmTokensArrivalDetector(
                    chainAsset: request.destination.chainAsset,
                    logger: self.logger
                )?.searchDepositInEvents(
                    effects.emittedEvents,
                    accountId: request.destination.accountId,
                    codingFactory: codingFactory
                )

                guard let depositEven else {
                    throw XcmDynamicCrosschainFeeCalculatorError.noDepositFound
                }

                let totalFee = initialModel.amountToSend.subtractOrZero(depositEven.amount)

                let feeModel = XcmFeeModel(
                    senderPart: intermediateResult.deliveryFee,
                    holdingPart: totalFee,
                    weightLimit: 0 // TODO: Fix weight limit
                )

                return feeModel
            }

            resultOperation.addDependency(codingFactoryOperation)
            resultOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: resultOperation)
        }
    }
}

extension XcmDynamicCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let updatedRequest = ensureSafeAmountToSend(for: request)

        let initialModelWrapper = createCallWrapper(for: updatedRequest)
        let originDryRunWrapper = dryRunOnOriginWrapper(
            for: updatedRequest,
            dependingOn: initialModelWrapper.targetOperation
        )

        originDryRunWrapper.addDependency(wrapper: initialModelWrapper)

        let reserveDryRunWrapper = dryRunReserveWrapper(
            for: updatedRequest,
            dependingOn: originDryRunWrapper.targetOperation
        )

        reserveDryRunWrapper.addDependency(wrapper: originDryRunWrapper)

        let destinationDryRunWrapper = dryRunDestinationWrapper(
            for: updatedRequest,
            dependingOn: reserveDryRunWrapper.targetOperation,
            initialOperation: initialModelWrapper.targetOperation
        )

        destinationDryRunWrapper.addDependency(wrapper: reserveDryRunWrapper)

        return destinationDryRunWrapper
            .insertingHead(operations: reserveDryRunWrapper.allOperations)
            .insertingHead(operations: originDryRunWrapper.allOperations)
            .insertingHead(operations: initialModelWrapper.allOperations)
    }
}
