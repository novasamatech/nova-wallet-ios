import Foundation
import Operation_iOS

enum HydraExchangeAtomicOperationError: Error {
    case noRoute
}

final class HydraExchangeAtomicOperation {
    typealias Edge = AssetsHydraExchangeEdgeProtocol & AssetExchangableGraphEdge

    let edges: [any Edge]
    let wallet: MetaAccountModel
    let operationArgs: AssetExchangeAtomicOperationArgs
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol
    let operationQueue: OperationQueue

    var assetIn: ChainAssetId? {
        edges.first?.origin
    }

    var assetOut: ChainAssetId? {
        edges.last?.destination
    }

    var chainId: ChainModel.Id? {
        assetIn?.chainId
    }

    init(
        wallet: MetaAccountModel,
        operationArgs: AssetExchangeAtomicOperationArgs,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol,
        edges: [any Edge],
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.operationArgs = operationArgs
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.extrinsicParamsFactory = extrinsicParamsFactory
        self.edges = edges
        self.operationQueue = operationQueue
    }

    private func createExtrinsicParamsWrapper(
        dependingOn selectedAccountOperation: BaseOperation<MetaChainAccountResponse>
    ) -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        guard let assetIn, let assetOut else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        let paramsWrapper = OperationCombiningService<HydraExchangeSwapParams>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let selectedAccount = try selectedAccountOperation.extractNoCancellableResultData()

            let routeComponents = self.edges.map(\.routeComponent)
            let route = HydraDx.RemoteSwapRoute(components: routeComponents)

            let callArgs = AssetConversion.CallArgs(
                assetIn: assetIn,
                amountIn: self.operationArgs.swapLimit.amountIn,
                assetOut: assetOut,
                amountOut: self.operationArgs.swapLimit.amountOut,
                receiver: selectedAccount.chainAccount.accountId,
                direction: self.operationArgs.swapLimit.direction,
                slippage: self.operationArgs.swapLimit.slippage,
                context: nil
            )

            return self.extrinsicParamsFactory.createOperationWrapper(for: route, callArgs: callArgs)
        }

        return paramsWrapper
    }

    private func createFeeWrapper(
        dependingOn selectedAccountOperation: BaseOperation<MetaChainAccountResponse>,
        chainOperation: BaseOperation<ChainModel>
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let paramsWrapper = createExtrinsicParamsWrapper(dependingOn: selectedAccountOperation)

        let feeWrapper = OperationCombiningService<ExtrinsicFeeProtocol>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let originChain = try chainOperation.extractNoCancellableResultData()

            let selectedAccount = try selectedAccountOperation.extractNoCancellableResultData()

            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            let extrinsicOperationFactory = self.extrinsicServiceFactory.createOperationFactory(
                account: selectedAccount.chainAccount,
                chain: originChain
            )

            let feeWrapper = extrinsicOperationFactory.estimateFeeOperation({ builder in
                try HydraExchangeExtrinsicConverter.addingOperation(
                    from: params,
                    builder: builder
                )
            }, payingIn: self.operationArgs.feeAsset)

            return feeWrapper
        }

        feeWrapper.addDependency(wrapper: paramsWrapper)

        return feeWrapper.insertingHead(operations: paramsWrapper.allOperations)
    }
}

extension HydraExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(for _: @escaping () throws -> Balance) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        guard let originChainId = chainId else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        let chainWrapper = chainRegistry.asyncWaitChainOrErrorWrapper(for: originChainId)
        let selectedAccountWrapper = wallet.fetchChainAccountWrapper(for: originChainId, using: chainRegistry)

        let feeWrapper = createFeeWrapper(
            dependingOn: selectedAccountWrapper.targetOperation,
            chainOperation: chainWrapper.targetOperation
        )

        feeWrapper.addDependency(wrapper: chainWrapper)
        feeWrapper.addDependency(wrapper: selectedAccountWrapper)

        let mappingOperation = ClosureOperation<AssetExchangeOperationFee> {
            let extrinsicFee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeOperationFee(extrinsicFee: extrinsicFee, args: self.operationArgs)
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: selectedAccountWrapper.allOperations)
            .insertingHead(operations: chainWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
