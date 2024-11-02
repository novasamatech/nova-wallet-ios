import Foundation
import Operation_iOS

final class AssetHubExchangeAtomicOperation {
    let host: AssetHubExchangeHostProtocol
    let edge: any AssetExchangableGraphEdge
    let operationArgs: AssetExchangeAtomicOperationArgs

    init(
        host: AssetHubExchangeHostProtocol,
        operationArgs: AssetExchangeAtomicOperationArgs,
        edge: any AssetExchangableGraphEdge
    ) {
        self.host = host
        self.operationArgs = operationArgs
        self.edge = edge
    }

    private func createFeeWrapper() -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        // TODO: Check whether we need to change direction
        let callArgs = AssetConversion.CallArgs(
            assetIn: edge.origin,
            amountIn: operationArgs.swapLimit.amountIn,
            assetOut: edge.destination,
            amountOut: operationArgs.swapLimit.amountOut,
            receiver: host.selectedAccount.accountId,
            direction: operationArgs.swapLimit.direction,
            slippage: operationArgs.swapLimit.slippage,
            context: nil
        )

        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let feeWrapper = host.extrinsicOperationFactory.estimateFeeOperation({ builder in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try AssetHubExtrinsicConverter.addingOperation(
                to: builder,
                chain: self.host.chain,
                args: callArgs,
                codingFactory: codingFactory
            )
        }, payingIn: operationArgs.feeAsset)

        feeWrapper.addDependency(operations: [codingFactoryOperation])

        return feeWrapper.insertingHead(operations: [codingFactoryOperation])
    }
}

extension AssetHubExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(
        for _: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
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
