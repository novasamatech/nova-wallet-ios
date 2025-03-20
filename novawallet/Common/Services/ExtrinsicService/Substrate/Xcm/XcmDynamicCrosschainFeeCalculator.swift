import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

final class XcmDynamicCrosschainFeeCalculator {
    struct IntermediateResult {
        let forwardedXcm: Xcm.Message
        let fee: BigUInt
    }

    static let maxWeight = BigUInt(UInt64.max) // TODO: Move to enum

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
    func createCallWrapper(
        for request: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<AnyRuntimeCall> {
        do {
            let xcmDerivationWrapper = callDerivator.createTransferCallDerivationWrapper(
                for: request,
                maxWeight: Self.maxWeight
            )

            let senderAccount = try request.origin.chain.emptyAccountId()

            let tokenMintWrapper = tokenMintingFactory.createTokenMintingWrapper(
                for: senderAccount,
                amount: request.amount,
                chainAsset: request.origin
            )

            let callBuilderOperation = ClosureOperation<AnyRuntimeCall> {
                let xcmCallCollector = try xcmDerivationWrapper.targetOperation.extractNoCancellableResultData()
                let tokenMintCollector = try tokenMintWrapper.targetOperation.extractNoCancellableResultData()

                var callBuilder: RuntimeCallBuilding = RuntimeCallBuilder()

                callBuilder = try xcmCallCollector
                    .addingToCall(builder: callBuilder, toEnd: true)
                    .dispatchingAs(.system(.signed(senderAccount)))

                return try tokenMintCollector.addingToCall(
                    builder: callBuilder,
                    toEnd: false
                )
                .batching(.batchAll)
                .build()
            }

            callBuilderOperation.addDependency(xcmDerivationWrapper.targetOperation)

            return xcmDerivationWrapper.insertingTail(operation: callBuilderOperation)
        } catch {
            return .createWithError(error)
        }
    }

    func dryRunOnOriginWrapper(
        for request: XcmUnweightedTransferRequest,
        dependingOn callOperation: BaseOperation<AnyRuntimeCall>,
        palletResolutionOperation: BaseOperation<String>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<IntermediateResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let call = try callOperation.extractNoCancellableResultData()

            let dryRunWrapper = self.dryRunOperationFactory.createDryRunCallWrapper(
                call,
                origin: .system(.root),
                chainId: request.origin.chain.chainId
            )

            let resultOperation = ClosureOperation<IntermediateResult> {
                let dryRunResult = try dryRunWrapper.targetOperation.extractNoCancellableResultData()
                let effects = try dryRunResult.ensureSuccessExecution()
                let palletName = try palletResolutionOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let deliveryFee = XcmDeliveryFeeMatcher(
                    palletName: palletName,
                    logger: self.logger
                ).matchEventList(
                    effects.emittedEvents,
                    using: codingFactory
                )

                throw CommonError.undefined
            }

            resultOperation.addDependency(dryRunWrapper.targetOperation)

            return dryRunWrapper.insertingTail(operation: resultOperation)
        }
    }
}

extension XcmDynamicCrosschainFeeCalculator: XcmCrosschainFeeCalculating {
    func crossChainFeeWrapper(
        request _: XcmUnweightedTransferRequest
    ) -> CompoundOperationWrapper<XcmFeeModelProtocol> {
        .createWithError(CommonError.undefined)
    }
}
