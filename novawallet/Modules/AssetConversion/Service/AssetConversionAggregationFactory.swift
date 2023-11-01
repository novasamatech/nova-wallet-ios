import Foundation
import RobinHood

protocol AssetConversionAggregationFactoryProtocol {
    func createAvailableDirectionsWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Set<ChainAssetId>>

    func createAvailableDirectionsWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>
}

enum AssetConversionAggregationFactoryError: Error {
    case unavailableProvider(ChainModel)
}

final class AssetConversionAggregationFactory {
    let operationQueue: OperationQueue
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func createAssetHubAllDirections(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return AssetHubSwapOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).availableDirections()
    }

    private func createAssetHubDirections(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return AssetHubSwapOperationFactory(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).availableDirectionsForAsset(chainAsset.chainAssetId)
    }
}

extension AssetConversionAggregationFactory: AssetConversionAggregationFactoryProtocol {
    func createAvailableDirectionsWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        if chainAsset.chain.hasSwapHub {
            return createAssetHubDirections(for: chainAsset)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chainAsset.chain)
            )
        }
    }

    func createAvailableDirectionsWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        if chain.hasSwapHub {
            return createAssetHubAllDirections(for: chain)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chain)
            )
        }
    }
}
