import Foundation
import Operation_iOS

enum HydraExchangeAtomicOperationError: Error {
    case noRoute
}

final class HydraExchangeAtomicOperation {
    typealias Edge = AssetsHydraExchangeEdgeProtocol & AssetExchangableGraphEdge

    let host: HydraSwapHostProtocol
    let edges: [any Edge]
    let operationArgs: AssetExchangeAtomicOperationArgs

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
        host: HydraSwapHostProtocol,
        operationArgs: AssetExchangeAtomicOperationArgs,
        edges: [any Edge]
    ) {
        self.host = host
        self.operationArgs = operationArgs
        self.edges = edges
    }

    private func createExtrinsicParamsWrapper() -> CompoundOperationWrapper<HydraExchangeSwapParams> {
        guard let assetIn, let assetOut else {
            return .createWithError(HydraExchangeAtomicOperationError.noRoute)
        }

        let routeComponents = edges.map(\.routeComponent)
        let route = HydraDx.RemoteSwapRoute(components: routeComponents)

        let callArgs = AssetConversion.CallArgs(
            assetIn: assetIn,
            amountIn: operationArgs.swapLimit.amountIn,
            assetOut: assetOut,
            amountOut: operationArgs.swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: operationArgs.swapLimit.direction,
            slippage: operationArgs.swapLimit.slippage,
            context: nil
        )

        return host.extrinsicParamsFactory.createOperationWrapper(for: route, callArgs: callArgs)
    }

    private func createFeeWrapper() -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let paramsWrapper = createExtrinsicParamsWrapper()

        let feeWrapper = OperationCombiningService<ExtrinsicFeeProtocol>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let params = try paramsWrapper.targetOperation.extractNoCancellableResultData()

            let feeWrapper = self.host.extrinsicOperationFactory.estimateFeeOperation({ builder in
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
        let feeWrapper = createFeeWrapper()

        let mappingOperation = ClosureOperation<AssetExchangeOperationFee> {
            let extrinsicFee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeOperationFee(extrinsicFee: extrinsicFee, args: self.operationArgs)
        }

        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper.insertingTail(operation: mappingOperation)
    }
}
