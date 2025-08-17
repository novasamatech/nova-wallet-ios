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
    let apiFactory: HydrationApiOperationFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry

        apiFactory = HydrationApiOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }
}

extension OrmlHydrationEvmWalletQueryFactory: OrmlHydrationEvmWalletQueryFactoryProtocol {
    func queryBalanceWrapper(
        for accountId: AccountId,
        chainAssetId: ChainAssetId,
        blockHash: BlockHashData?
    ) -> CompoundOperationWrapper<AssetBalance> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAssetId.chainId)
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
                chainId: chain.chainId,
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
