import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

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
        let amountToSend: Balance
    }

    static let minimumSendAmount: Decimal = 100
    static let minimumFundAmount: Decimal = minimumSendAmount * 2

    let chainRegistry: ChainRegistryProtocol
    let callDerivator: XcmCallDerivating
    let tokenMintingFactory: TokenBalanceMintingFactoryProtocol
    let dryRunner: XcmTransferDryRunning

    init(
        chainRegistry: ChainRegistryProtocol,
        callDerivator: XcmCallDerivating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.callDerivator = callDerivator

        dryRunner = XcmTransferDryRunner(
            chainRegistry: chainRegistry,
            dryRunOperationFactory: DryRunOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            palletMetadataQueryFactory: XcmPalletMetadataQueryFactory(),
            operationQueue: operationQueue,
            logger: logger
        )

        tokenMintingFactory = TokenBalanceMintingFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
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
}

extension XcmDynamicCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        let updatedRequest = ensureSafeAmountToSend(for: request)

        let initialModelWrapper = createDryCallWrapper(for: updatedRequest)
        let dryRunWrapper = dryRunner.createDryRunWrapper(
            for: request,
            paramsClosure: {
                let initialModel = try initialModelWrapper.targetOperation.extractNoCancellableResultData()
                return XcmTransferDryRunParams(
                    callOrigin: .system(.root),
                    call: initialModel.call,
                    amountToSend: initialModel.amountToSend
                )
            }
        )

        dryRunWrapper.addDependency(wrapper: initialModelWrapper)

        return dryRunWrapper.insertingHead(operations: initialModelWrapper.allOperations)
    }
}
