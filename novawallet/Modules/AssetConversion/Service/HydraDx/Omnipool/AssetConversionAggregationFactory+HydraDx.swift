import Foundation
import RobinHood

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

        return HydraTokensFactory.createWithDefaultPools(
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

        return HydraTokensFactory.createWithDefaultPools(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).availableDirectionsForAsset(chainAsset.chainAssetId)
    }

    func createHydraQuote(
        for state: HydraFlowState,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let omnipoolTokensFactory = HydraOmnipoolTokensFactory(
            chain: state.chain,
            runtimeService: state.runtimeProvider,
            connection: state.connection,
            operationQueue: state.operationQueue
        )

        let stableswapTokensFactory = HydraStableSwapsTokensFactory(
            chain: state.chain,
            runtimeService: state.runtimeProvider,
            connection: state.connection,
            operationQueue: state.operationQueue
        )

        return HydraQuoteFactory(
            flowState: state,
            omnipoolTokensFactory: omnipoolTokensFactory,
            stableswapTokensFactory: stableswapTokensFactory
        ).quote(for: args)
    }

    func createHydraCanPayFee(for chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.connectionUnavailable)
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return .createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        return HydraTokensFactory.createWithDefaultPools(
            chain: chainAsset.chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        ).canPayFee(in: chainAsset.chainAssetId)
    }
}
