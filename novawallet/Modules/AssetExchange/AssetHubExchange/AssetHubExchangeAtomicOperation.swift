import Foundation
import Operation_iOS

final class AssetHubExchangeAtomicOperation {
    let edge: any AssetExchangableGraphEdge
    let wallet: MetaAccountModel
    let operationArgs: AssetExchangeAtomicOperationArgs
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        operationArgs: AssetExchangeAtomicOperationArgs,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        edge: any AssetExchangableGraphEdge,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.operationArgs = operationArgs
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.edge = edge
        self.operationQueue = operationQueue
    }

    private func createFeeWrapper(
        dependingOn chainOperation: BaseOperation<ChainModel?>,
        selectedAccountOperation: BaseOperation<MetaChainAccountResponse>
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        OperationCombiningService<ExtrinsicFeeProtocol>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let optOriginChain = try chainOperation.extractNoCancellableResultData()
            let originChain = try optOriginChain.mapOrThrow(ChainRegistryError.noChain(self.edge.origin.chainId))

            let runtimeProvider = try self.chainRegistry.getRuntimeProviderOrError(for: originChain.chainId)

            let selectedAccount = try selectedAccountOperation.extractNoCancellableResultData()

            // TODO: Check whether we need to change direction
            let callArgs = AssetConversion.CallArgs(
                assetIn: self.edge.origin,
                amountIn: self.operationArgs.swapLimit.amountIn,
                assetOut: self.edge.destination,
                amountOut: self.operationArgs.swapLimit.amountOut,
                receiver: selectedAccount.chainAccount.accountId,
                direction: self.operationArgs.swapLimit.direction,
                slippage: self.operationArgs.swapLimit.slippage,
                context: nil
            )

            let extrinsicOperationFactory = self.extrinsicServiceFactory.createOperationFactory(
                account: selectedAccount.chainAccount,
                chain: originChain
            )

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let feeWrapper = extrinsicOperationFactory.estimateFeeOperation({ builder in
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                return try AssetHubExtrinsicConverter.addingOperation(
                    to: builder,
                    chain: originChain,
                    args: callArgs,
                    codingFactory: codingFactory
                )
            }, payingIn: self.operationArgs.feeAsset)

            feeWrapper.addDependency(operations: [codingFactoryOperation])

            return feeWrapper.insertingHead(operations: [codingFactoryOperation])
        }
    }
}

extension AssetHubExchangeAtomicOperation: AssetExchangeAtomicOperationProtocol {
    func executeWrapper(
        for _: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<Balance> {
        CompoundOperationWrapper.createWithError(CommonError.undefined)
    }

    func estimateFee() -> CompoundOperationWrapper<AssetExchangeOperationFee> {
        let originChainId = edge.origin.chainId
        let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: originChainId)
        let selectedAccountWrapper = wallet.fetchChainAccountWrapper(for: originChainId, using: chainRegistry)

        let feeWrapper = createFeeWrapper(
            dependingOn: chainWrapper.targetOperation,
            selectedAccountOperation: selectedAccountWrapper.targetOperation
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
