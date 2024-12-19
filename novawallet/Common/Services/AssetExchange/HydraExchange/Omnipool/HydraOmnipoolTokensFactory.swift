import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraOmnipoolTokensFactory {
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

    func fetchAllRemoteAssets() -> CompoundOperationWrapper<Set<HydraDx.AssetId>> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let hubAssetIdOperation = PrimitiveConstantOperation<HydraDx.AssetId>.operation(
            for: HydraOmnipool.hubAssetIdPath,
            dependingOn: codingFactoryOperation
        )

        hubAssetIdOperation.addDependency(codingFactoryOperation)

        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraOmnipool.assetsPath,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Set<HydraDx.AssetId>> {
            let allAssets = try assetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            let hubAssetId = try hubAssetIdOperation.extractNoCancellableResultData()

            let filteredAssets = allAssets.compactMap { $0.assetId != hubAssetId ? $0.assetId : nil }

            return Set(filteredAssets)
        }

        mapOperation.addDependency(hubAssetIdOperation)
        mapOperation.addDependency(assetsFetchWrapper.targetOperation)

        return assetsFetchWrapper
            .insertingHead(operations: [codingFactoryOperation, hubAssetIdOperation])
            .insertingTail(operation: mapOperation)
    }

    func fetchAllAssets() -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let remoteWrapper = fetchAllRemoteAssets()

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let allLocalAssets = chain.assets.map { ChainAsset(chain: chain, asset: $0) }
        let localAssetsOperation = ClosureOperation<Set<ChainAssetId>> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let localRemoteAssets = try allLocalAssets.reduce(
                into: [HydraDx.AssetId: ChainAssetId]()
            ) { accum, chainAsset in
                let pair = try HydraDxTokenConverter.convertToRemote(
                    chainAsset: chainAsset,
                    codingFactory: codingFactory
                )

                accum[pair.remoteAssetId] = pair.localAssetId
            }

            let remoteAssets = try remoteWrapper.targetOperation.extractNoCancellableResultData()

            return Set(remoteAssets.compactMap { localRemoteAssets[$0] })
        }

        localAssetsOperation.addDependency(codingFactoryOperation)
        localAssetsOperation.addDependency(remoteWrapper.targetOperation)

        return remoteWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: localAssetsOperation)
    }
}

extension HydraOmnipoolTokensFactory: HydraPoolTokensFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let allAssetsWrapper = fetchAllAssets()

        let mappingOperation = ClosureOperation<[ChainAssetId: Set<ChainAssetId>]> {
            let allAssets = try allAssetsWrapper.targetOperation.extractNoCancellableResultData()

            return allAssets.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, chainAssetId in
                accum[chainAssetId] = allAssets.subtracting([chainAssetId])
            }
        }

        mappingOperation.addDependency(allAssetsWrapper.targetOperation)

        return allAssetsWrapper.insertingTail(operation: mappingOperation)
    }

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let allAssetsWrapper = fetchAllAssets()

        let mappingOperation = ClosureOperation<Set<ChainAssetId>> {
            let allAssets = try allAssetsWrapper.targetOperation.extractNoCancellableResultData()

            guard allAssets.contains(chainAssetId) else {
                return []
            }

            return allAssets.subtracting([chainAssetId])
        }

        mappingOperation.addDependency(allAssetsWrapper.targetOperation)

        return allAssetsWrapper.insertingTail(operation: mappingOperation)
    }
}
