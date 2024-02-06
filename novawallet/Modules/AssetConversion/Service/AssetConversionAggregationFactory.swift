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
        for state: AssetConversionFlowState,
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
}

extension AssetConversionAggregationFactory: AssetConversionAggregationFactoryProtocol {
    func createAvailableDirectionsWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        if chainAsset.chain.hasSwapHub {
            return createAssetHubDirections(for: chainAsset)
        } else if chainAsset.chain.hasSwapHydra {
            return createHydraDirections(for: chainAsset)
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
        } else if chain.hasSwapHydra {
            return createHydraAllDirections(for: chain)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chain)
            )
        }
    }

    func createQuoteWrapper(
        for state: AssetConversionFlowState,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        switch state {
        case let .assetHub(assetHub):
            _ = assetHub.setupReQuoteService()
            return createAssetHubQuote(for: assetHub, args: args)
        case let .hydraOmnipool(hydra):
            return createHydraQuote(for: hydra, args: args)
        }
    }

    func createCanPayFeeWrapper(in chainAsset: ChainAsset) -> CompoundOperationWrapper<Bool> {
        if chainAsset.chain.hasSwapHub {
            return createAssetHubCanPayFee(for: chainAsset)
        } else if chainAsset.chain.hasSwapHydra {
            return createHydraCanPayFee(for: chainAsset)
        } else {
            return CompoundOperationWrapper.createWithError(
                AssetConversionAggregationFactoryError.unavailableProvider(chainAsset.chain)
            )
        }
    }
}
