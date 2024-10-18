import Foundation
import Operation_iOS

protocol AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]>
}

protocol AssetsExchangeProviding {
    func provide(notifingIn queue: DispatchQueue, onChange: @escaping ([AssetsExchangeProtocol]) -> Void)
}
