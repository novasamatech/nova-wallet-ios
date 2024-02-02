import Foundation
import RobinHood

protocol AssetConversionAggregationFactoryProtocol {
    func createAvailableDirectionsWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Set<ChainAssetId>>

    func createAvailableDirectionsWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>

    func createQuoteWrapper(
        for chain: ChainModel,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote>

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool>
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

    private func createAssetHubQuote(
        for chain: ChainModel,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
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
        ).quote(for: args)
    }

    private func createAssetHubCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
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
        ).canPayFee(in: chainAsset.chainAssetId)
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

    func createQuoteWrapper(
        for chain: ChainModel,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        if chain.hasSwapHub {
            return createAssetHubQuote(for: chain, args: args)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chain)
            )
        }
    }

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        if chainAsset.chain.hasSwapHub {
            return createAssetHubCanPayFee(for: chainAsset)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chainAsset.chain)
            )
        }
    }
}
