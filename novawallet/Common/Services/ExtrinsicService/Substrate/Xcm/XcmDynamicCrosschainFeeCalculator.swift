import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum XcmDynamicCrosschainFeeCalculatorError: Error {
    case emptyForwardedMessages
    case noForwardedMessage
    case noDepositFound
}

/**
 *  This class estimates the fee for an XCM (Cross-Consensus Message) transaction using dry runs.
 *
 *  The process involves the following steps:
 *    1. Derive the initial XCM call.
 *    2. Create a temporary (empty) sender account and prepare additional calls to top it up.
 *    3. Batch the top-up call with the XCM call and perform a dry run on the origin chain.
 *    4. Extract the forwarded XCM message and delivery fee from the dry run result.
 *    5. Perform a dry run of the extracted XCM message on the reserve chain.
 *    6. Extract the next forwarded XCM message from the result.
 *    7. Perform a dry run of the final XCM message on the destination chain.
 *    8. Determine the received (arrived) amount.
 *    9. Calculate the execution fee as the difference between the sent and received amounts.
 *
 *  This process helps to estimate the total cost of executing an XCM call across multiple chains.
 */
final class XcmDynamicCrosschainFeeCalculator {
    struct MintingCalls {
        let targetTokenMintCollector: RuntimeCallCollecting
        let nativeTokenMintCollector: RuntimeCallCollecting?
    }

    struct InitialModel {
        let call: AnyRuntimeCall
        let sender: AccountId
        let amountToSend: Balance
    }

    struct IntermediateResult {
        let forwardedXcm: XcmUni.VersionedMessage
        let deliveryFee: BigUInt
    }

    static let minimumSendAmount: Decimal = 100
    static let minimumFundAmount: Decimal = minimumSendAmount * 2
    static let dryRunXcmVersion: Xcm.Version = .V4

    let chainRegistry: ChainRegistryProtocol
    let dryRunOperationFactory: DryRunOperationFactoryProtocol
    let callDerivator: XcmCallDerivating
    let palletMetadataQueryFactory: XcmPalletMetadataQueryFactoryProtocol
    let tokenMintingFactory: TokenBalanceMintingFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        callDerivator: XcmCallDerivating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.callDerivator = callDerivator

        dryRunOperationFactory = DryRunOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

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

    func prepareAccountSetupCallsForDryRun(
        for request: XcmUnweightedTransferRequest,
        senderAccount: AccountId
    ) -> CompoundOperationWrapper<MintingCalls> {
        let amountToFund = ensureSafeAmountToFund(
            for: request.amount,
            chainAsset: request.origin.chainAsset
        )

        let targetTokenMintWrapper = tokenMintingFactory.createTokenMintingWrapper(
            for: senderAccount,
            amount: amountToFund,
            chainAsset: request.origin.chainAsset
        )

        var dependencies: [Operation] = targetTokenMintWrapper.allOperations

        let nativeTokenMintWrapper: CompoundOperationWrapper<RuntimeCallCollecting>?

        if
            !request.origin.chainAsset.isUtilityAsset,
            let nativeAsset = request.originChain.utilityChainAsset() {
            let nativeAmountToFund = ensureSafeAmountToFund(for: nil, chainAsset: nativeAsset)

            let wrapper = tokenMintingFactory.createTokenMintingWrapper(
                for: senderAccount,
                amount: nativeAmountToFund,
                chainAsset: nativeAsset
            )

            dependencies.append(contentsOf: wrapper.allOperations)

            nativeTokenMintWrapper = wrapper

        } else {
            nativeTokenMintWrapper = nil
        }

        let mergeOperation = ClosureOperation<MintingCalls> {
            let targetMintCollector = try targetTokenMintWrapper.targetOperation.extractNoCancellableResultData()
            let nativeMintCollector = try nativeTokenMintWrapper?.targetOperation.extractNoCancellableResultData()

            return MintingCalls(
                targetTokenMintCollector: targetMintCollector,
                nativeTokenMintCollector: nativeMintCollector
            )
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func createDryCallWrapper(for request: XcmUnweightedTransferRequest) -> CompoundOperationWrapper<InitialModel> {
        do {
            let xcmDerivationWrapper = callDerivator.createTransferCallDerivationWrapper(for: request)

            let senderAccount = try request.originChain.emptyAccountId()

            let mintingCallsWrapper = prepareAccountSetupCallsForDryRun(
                for: request,
                senderAccount: senderAccount
            )

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: request.originChain.chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let callBuilderOperation = ClosureOperation<InitialModel> {
                let xcmCallCollector = try xcmDerivationWrapper.targetOperation.extractNoCancellableResultData()
                let mintingCalls = try mintingCallsWrapper.targetOperation.extractNoCancellableResultData()

                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                var callBuilder: RuntimeCallBuilding = RuntimeCallBuilder(
                    context: codingFactory.createRuntimeJsonContext()
                )

                callBuilder = try xcmCallCollector
                    .addingToCall(builder: callBuilder, toEnd: true)
                    .dispatchingAs(.system(.signed(senderAccount)))

                callBuilder = try mintingCalls.targetTokenMintCollector.addingToCall(
                    builder: callBuilder,
                    toEnd: false
                )

                if let nativeMintCollector = mintingCalls.nativeTokenMintCollector {
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
            callBuilderOperation.addDependency(mintingCallsWrapper.targetOperation)
            callBuilderOperation.addDependency(xcmDerivationWrapper.targetOperation)

            return xcmDerivationWrapper
                .insertingHead(operations: mintingCallsWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: callBuilderOperation)

        } catch {
            return .createWithError(error)
        }
    }

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
            throw XcmDynamicCrosschainFeeCalculatorError.emptyForwardedMessages
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
            throw XcmDynamicCrosschainFeeCalculatorError.noForwardedMessage
        }

        return IntermediateResult(forwardedXcm: forwardedMessage, deliveryFee: deliveryFee ?? 0)
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
            throw XcmDynamicCrosschainFeeCalculatorError.emptyForwardedMessages
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
            throw XcmDynamicCrosschainFeeCalculatorError.noForwardedMessage
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
        initialModel: InitialModel,
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
            throw XcmDynamicCrosschainFeeCalculatorError.noDepositFound
        }

        let totalFee = initialModel.amountToSend.subtractOrZero(depositEven.amount)

        let feeModel = XcmFeeModel(
            senderPart: reserveResult.deliveryFee,
            holdingPart: totalFee
        )

        return feeModel
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
                    initialModel: initialModel,
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

extension XcmDynamicCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let updatedRequest = ensureSafeAmountToSend(for: request)

        let initialModelWrapper = createDryCallWrapper(for: updatedRequest)
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
