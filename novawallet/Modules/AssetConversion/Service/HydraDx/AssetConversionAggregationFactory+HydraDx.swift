import Foundation

extension AssetConversionAggregationFactory {
    func createHydraAllDirections(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        return HydraOmnipoolOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).availableDirections()
    }

    func createHydraDirections(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }
        
        return HydraOmnipoolOperationFactory(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).availableDirectionsForAsset(chainAsset.chainAssetId)
    }

    func createHydraQuote(
        for state: HydraOmnipoolFlowState,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        return HydraOmnipoolQuoteFactory(flowState: state).quote(for: args)
    }

    func createHydraCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return HydraOmnipoolOperationFactory(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).canPayFee(in: chainAsset.chainAssetId)
    }
}
