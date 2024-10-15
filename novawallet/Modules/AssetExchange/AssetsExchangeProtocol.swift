import Foundation
import Operation_iOS

protocol AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>
    
    func createAvailableDirectionsWrapper(
        for chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Set<ChainAssetId>>
}
