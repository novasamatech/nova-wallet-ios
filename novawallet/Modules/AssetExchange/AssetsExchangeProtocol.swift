import Foundation
import Operation_iOS

enum AssetsExchange {
    typealias AvailableAssets = Set<ChainAssetId>
    typealias Directions = [ChainAssetId: AvailableAssets]
}

protocol AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<AssetsExchange.Directions>

    func createAvailableDirectionsWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetsExchange.AvailableAssets>
}

protocol AssetsExchangeProviding {
    func provide(notifingIn queue: DispatchQueue, onChange: @escaping ([AssetsExchangeProtocol]) -> Void)
}
