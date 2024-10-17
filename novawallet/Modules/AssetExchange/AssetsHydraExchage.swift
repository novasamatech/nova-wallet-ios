import Foundation
import Operation_iOS

typealias AssetsHydraOmnipoolExchange = HydraOmnipoolTokensFactory

extension AssetsHydraOmnipoolExchange: AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<AssetsExchange.Directions> {
        availableDirections()
    }

    func createAvailableDirectionsWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetsExchange.AvailableAssets> {
        availableDirectionsForAsset(chainAssetId)
    }
}

typealias AssetsHydraStableSwapExchange = HydraStableSwapsTokensFactory

extension AssetsHydraStableSwapExchange: AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<AssetsExchange.Directions> {
        availableDirections()
    }

    func createAvailableDirectionsWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetsExchange.AvailableAssets> {
        availableDirectionsForAsset(chainAssetId)
    }
}

typealias AssetsHydraXYKExchange = HydraXYKPoolTokensFactory

extension AssetsHydraXYKExchange: AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<AssetsExchange.Directions> {
        availableDirections()
    }

    func createAvailableDirectionsWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetsExchange.AvailableAssets> {
        availableDirectionsForAsset(chainAssetId)
    }
}
