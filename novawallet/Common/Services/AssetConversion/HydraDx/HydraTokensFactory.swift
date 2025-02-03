import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol HydraPoolTokensFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>>
}

protocol HydraTokensFactoryProtocol: HydraPoolTokensFactoryProtocol {
    func canPayFee(in chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool>
    func fallbackFeePrice(for chainAssetId: ChainAssetId) -> CompoundOperationWrapper<BigRational?>
}

final class HydraTokensFactory {
    let poolsFactory: [HydraPoolTokensFactoryProtocol]
    let chain: ChainModel
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        poolsFactory: [HydraPoolTokensFactoryProtocol],
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.poolsFactory = poolsFactory
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationQueue = operationQueue
    }

    private func createRemoteFeeAssetsWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Set<HydraDx.AssetId>> {
        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraDx.feeCurrenciesPath,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Set<HydraDx.AssetId>> {
            let allAssets = try assetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            return Set(allAssets.map(\.assetId))
        }

        mapOperation.addDependency(assetsFetchWrapper.targetOperation)

        return assetsFetchWrapper.insertingTail(operation: mapOperation)
    }
}

extension HydraTokensFactory: HydraTokensFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let wrappers = poolsFactory.map { $0.availableDirections() }

        let mergeOperation = ClosureOperation<[ChainAssetId: Set<ChainAssetId>]> {
            let pairPools = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            let graph = GraphModelFactory.createFromConnections(pairPools)

            return graph.connections.keys.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, asset in
                accum[asset] = graph.calculateReachableNodes(for: asset, filter: .allEdges())
            }
        }

        wrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let wrappers = poolsFactory.map { $0.availableDirections() }

        let mergeOperation = ClosureOperation<Set<ChainAssetId>> {
            let pairPools = try wrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            let graph = GraphModelFactory.createFromConnections(pairPools)

            return graph.calculateReachableNodes(for: chainAssetId, filter: .allEdges())
        }

        wrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
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

    func fallbackFeePrice(for chainAssetId: ChainAssetId) -> CompoundOperationWrapper<BigRational?> {
        do {
            let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)
            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let requestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )

            let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
            fetchWrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: {
                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                    let conversion = try HydraDxTokenConverter.convertToRemote(
                        chainAsset: chainAsset,
                        codingFactory: codingFactory
                    )

                    let remoteAssetId = conversion.remoteAssetId

                    return [StringScaleMapper(value: remoteAssetId)]

                }, factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: HydraDx.feeCurrenciesPath
            )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mapOperation = ClosureOperation<BigRational?> {
                let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                guard let price = responses.first?.value?.value else {
                    return nil
                }

                return .fixedU128(value: price)
            }

            mapOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }
}

extension HydraTokensFactory {
    static func createWithDefaultPools(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) -> HydraTokensFactory {
        let omnipool = HydraOmnipoolTokensFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let stableswap = HydraStableswapTokensFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let xykswap = HydraXYKPoolTokensFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        return .init(
            poolsFactory: [omnipool, stableswap, xykswap],
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
    }
}
