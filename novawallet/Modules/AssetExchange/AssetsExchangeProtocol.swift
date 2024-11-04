import Foundation
import Operation_iOS

protocol AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]>
}

protocol AssetsExchangeProviding: AnyObject {
    func setup()
    func throttle()

    func subscribeExchanges(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping ([AssetsExchangeProtocol]) -> Void
    )

    func unsubscribeExchanges(_ target: AnyObject)

    func inject(graph: AssetsExchangeGraphProtocol)
}

protocol AssetsExchangeGraphProviding {
    func setup()
    func throttle()

    func subscribeGraph(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetsExchangeGraphProtocol?) -> Void
    )

    func unsubscribeGraph(_ target: AnyObject)
}
