import Foundation
import Operation_iOS
import SubstrateSdk

protocol OrmlHydrationEvmWalletQueryFactoryProtocol {
    func queryBalanceWrapper(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        blockHash: BlockHashData?
    ) -> CompoundOperationWrapper<AssetBalance>
}

extension OrmlHydrationEvmWalletQueryFactoryProtocol {
    func queryBalanceWrapper(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetBalance> {
        queryBalanceWrapper(
            for: accountId,
            chainAssetId: chainAssetId,
            blockHash: nil
        )
    }
}

final class OrmlHydrationEvmWalletQueryFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

extension OrmlHydrationEvmWalletQueryFactory: OrmlHydrationEvmWalletQueryFactoryProtocol {
    func queryBalanceWrapper(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        blockHash: BlockHashData?
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            let runtimeConnectionProvider = ChainRegistryRuntimeConnectionStore(
                chainId: chainAssetId.chainId,
                chainRegistry: chainRegistry
            )

            let apiFactory = HydrationApiOperationFactory(
                runtimeConnectionStore: runtimeConnectionProvider,
                operationQueue: operationQueue
            )

            let runtimeProvider = try runtimeConnectionProvider.getRuntimeProvider()
            let chain = try chainRegistry.getChainOrError(for: chainAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)
            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let queryWrapper = apiFactory.createCurrencyBalanceWrapper(
                for: {
                    let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

                    return try HydraDxTokenConverter.convertToRemote(
                        chainAsset: chainAsset,
                        codingFactory: codingFactory
                    ).remoteAssetId
                },
                accountId: accountId,
                blockHash: blockHash?.toHex(includePrefix: true)
            )

            queryWrapper.addDependency(operations: [coderFactoryOperation])

            let mappingOperation = ClosureOperation<AssetBalance> {
                let data = try queryWrapper.targetOperation.extractNoCancellableResultData()

                return AssetBalance(
                    hydrationCurrencyData: data,
                    chainAssetId: chainAssetId,
                    accountId: accountId
                )
            }

            mappingOperation.addDependency(queryWrapper.targetOperation)

            return queryWrapper
                .insertingHead(operations: [coderFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
