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
        for amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = host.runtimeService.fetchCoderFactoryOperation()

        let executeWrapper = OperationCombiningService<Balance>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let amount = try amountClosure()

            let callArgs = AssetConversion.CallArgs(
                assetIn: self.edge.origin,
                amountIn: amount,
                assetOut: self.edge.destination,
                amountOut: self.operationArgs.swapLimit.amountOut,
                receiver: self.host.selectedAccount.accountId,
                direction: self.operationArgs.swapLimit.direction,
                slippage: self.operationArgs.swapLimit.slippage,
                context: nil
            )

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let submittionWrapper = self.host.extrinsicOperationFactory.submit({ builder in
                try AssetHubExtrinsicConverter.addingOperation(
                    to: builder,
                    chain: self.host.chain,
                    args: callArgs,
                    codingFactory: codingFactory
                )
            }, signer: self.host.signingWrapper, payingIn: self.operationArgs.feeAsset)

            // TODO: Replace with monitoring to understand actual amount received
            let monitorOperation = ClosureOperation<Balance> {
                _ = try submittionWrapper.targetOperation.extractNoCancellableResultData()

                return self.operationArgs.swapLimit.amountOut
            }

            monitorOperation.addDependency(submittionWrapper.targetOperation)

            return submittionWrapper.insertingTail(operation: monitorOperation)
        }

        executeWrapper.addDependency(operations: [codingFactoryOperation])

        return executeWrapper.insertingHead(operations: [codingFactoryOperation])
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
