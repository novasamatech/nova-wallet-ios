import Foundation
import Operation_iOS
import SubstrateSdk

final class HydraStableSwapsTokensFactory {
    let chain: ChainModel
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationQueue = operationQueue
    }

    private func fetchAllPoolAssets(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[HydraDx.AssetId]> {
        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let poolAssetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraStableswap.pools,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        poolAssetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let poolAssetsMapOperation = ClosureOperation<[HydraDx.AssetId]> {
            let allAssets = try poolAssetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            return Array(allAssets.map(\.assetId))
        }

        poolAssetsMapOperation.addDependency(poolAssetsFetchWrapper.targetOperation)

        return poolAssetsFetchWrapper.insertingTail(operation: poolAssetsMapOperation)
    }

    private func fetchAllPools(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[HydraDx.AssetId: [HydraDx.AssetId]]> {
        let poolAssetsWrapper = fetchAllPoolAssets(dependingOn: codingFactoryOperation)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let poolsWrapper: CompoundOperationWrapper<[StorageResponse<HydraStableswap.PoolInfo>]>
        poolsWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: {
                let assets = try poolAssetsWrapper.targetOperation.extractNoCancellableResultData()

                return assets.map { StringScaleMapper(value: $0) }
            },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: HydraStableswap.pools
        )

        poolsWrapper.addDependency(wrapper: poolAssetsWrapper)

        let mapOperation = ClosureOperation<[HydraDx.AssetId: [HydraDx.AssetId]]> {
            let poolAssets = try poolAssetsWrapper.targetOperation.extractNoCancellableResultData()
            let pools = try poolsWrapper.targetOperation.extractNoCancellableResultData()

            return zip(poolAssets, pools).reduce(
                into: [HydraDx.AssetId: [HydraDx.AssetId]]()
            ) { accum, poolAndInfo in
                let poolAsset = poolAndInfo.0
                let assets = poolAndInfo.1.value.map { $0.assets.map(\.value) }

                accum[poolAsset] = assets
            }
        }

        mapOperation.addDependency(poolsWrapper.targetOperation)

        let dependencies = poolAssetsWrapper.allOperations + poolsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func fetchAllLocalPairs(for chain: ChainModel) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let remotePoolsWrapper = fetchAllPools(dependingOn: codingFactoryOperation)

        remotePoolsWrapper.addDependency(operations: [codingFactoryOperation])

        let conversionOperation = ClosureOperation<[ChainAssetId: Set<ChainAssetId>]> {
            let pools = try remotePoolsWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let allLocalAssets = chain.assets.map { ChainAsset(chain: chain, asset: $0) }
            let localRemoteAssets = try allLocalAssets.reduce(
                into: [HydraDx.AssetId: ChainAssetId]()
            ) { accum, chainAsset in
                let pair = try HydraDxTokenConverter.convertToRemote(
                    chainAsset: chainAsset,
                    codingFactory: codingFactory
                )

                accum[pair.remoteAssetId] = pair.localAssetId
            }

            return pools.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, keyValue in
                let poolAssets = ([keyValue.key] + keyValue.value).compactMap { localRemoteAssets[$0] }
                let poolAssetSet = Set(poolAssets)

                for asset in poolAssets {
                    accum[asset] = (accum[asset] ?? Set()).union(poolAssetSet.subtracting([asset]))
                }
            }
        }

        conversionOperation.addDependency(remotePoolsWrapper.targetOperation)

        return remotePoolsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: conversionOperation)
    }

    private func fetchAllLocalPoolAssets(for chain: ChainModel) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let fetchWrapper = fetchAllPoolAssets(dependingOn: codingFactoryOperation)

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        let conversionOperation = ClosureOperation<Set<ChainAssetId>> {
            let poolAssets = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let allLocalAssets = chain.assets.map { ChainAsset(chain: chain, asset: $0) }
            let localRemoteAssets = try allLocalAssets.reduce(
                into: [HydraDx.AssetId: ChainAssetId]()
            ) { accum, chainAsset in
                let pair = try HydraDxTokenConverter.convertToRemote(
                    chainAsset: chainAsset,
                    codingFactory: codingFactory
                )

                accum[pair.remoteAssetId] = pair.localAssetId
            }

            return Set(poolAssets.compactMap { localRemoteAssets[$0] })
        }

        conversionOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: conversionOperation)
    }
}

extension HydraStableSwapsTokensFactory: HydraPoolTokensFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        fetchAllLocalPairs(for: chain)
    }

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let allPairsWrapper = fetchAllLocalPairs(for: chain)

        let mapOperation = ClosureOperation<Set<ChainAssetId>> {
            let allPairs = try allPairsWrapper.targetOperation.extractNoCancellableResultData()

            return allPairs[chainAssetId] ?? Set()
        }

        mapOperation.addDependency(allPairsWrapper.targetOperation)

        return allPairsWrapper.insertingTail(operation: mapOperation)
    }

    func fetchAllLocalPoolAssets() -> CompoundOperationWrapper<Set<ChainAssetId>> {
        fetchAllLocalPoolAssets(for: chain)
    }
}
