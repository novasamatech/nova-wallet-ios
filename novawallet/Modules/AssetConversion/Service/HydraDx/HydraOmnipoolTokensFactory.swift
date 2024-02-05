import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol HydraOmnipoolTokensFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>>

    func canPayFee(in chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool>
}

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

    private func createRemoteFeeAssetsWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Set<HydraDx.OmniPoolAssetId>> {
        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraDx.feeCurrencies,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Set<HydraDx.OmniPoolAssetId>> {
            let allAssets = try assetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            return Set(allAssets.map(\.assetId))
        }

        mapOperation.addDependency(assetsFetchWrapper.targetOperation)

        return assetsFetchWrapper.insertingTail(operation: mapOperation)
    }

    private func fetchAllRemoteAssets() -> CompoundOperationWrapper<Set<HydraDx.OmniPoolAssetId>> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let hubAssetIdOperation = PrimitiveConstantOperation<HydraDx.OmniPoolAssetId>.operation(
            for: HydraDx.hubAssetIdPath,
            dependingOn: codingFactoryOperation
        )

        hubAssetIdOperation.addDependency(codingFactoryOperation)

        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraDx.omnipoolAssets,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Set<HydraDx.OmniPoolAssetId>> {
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
                into: [HydraDx.OmniPoolAssetId: ChainAssetId]()
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

extension HydraOmnipoolTokensFactory: HydraOmnipoolTokensFactoryProtocol {
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

    func canPayFee(in chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool> {
        guard let asset = chain.asset(for: chainAssetId.assetId) else {
            return CompoundOperationWrapper.createWithResult(false)
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        if chainAsset.isUtilityAsset {
            return CompoundOperationWrapper.createWithResult(true)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let allFeeRemoteAssets = createRemoteFeeAssetsWrapper(dependingOn: codingFactoryOperation)

        allFeeRemoteAssets.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<Bool> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let remoteAssetId = try HydraDxTokenConverter.convertToRemote(
                chainAsset: chainAsset,
                codingFactory: codingFactory
            )

            let allFeeRemoteAssets = try allFeeRemoteAssets.targetOperation.extractNoCancellableResultData()

            return allFeeRemoteAssets.contains(remoteAssetId.remoteAssetId)
        }

        mappingOperation.addDependency(allFeeRemoteAssets.targetOperation)
        mappingOperation.addDependency(codingFactoryOperation)

        return allFeeRemoteAssets
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}
