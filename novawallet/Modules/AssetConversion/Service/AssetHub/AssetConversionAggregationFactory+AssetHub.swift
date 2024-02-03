import Foundation

extension AssetConversionAggregationFactory {
    func createAssetHubAllDirections(
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

    func createAssetHubDirections(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Set<ChainAssetId>> {
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

    func createAssetHubQuote(
        for state: AssetHubFlowState,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        return AssetHubSwapOperationFactory(
            chain: state.chain,
            runtimeService: state.runtimeProvider,
            connection: state.connection,
            operationQueue: operationQueue
        ).quote(for: args)
    }

    func createAssetHubCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
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
