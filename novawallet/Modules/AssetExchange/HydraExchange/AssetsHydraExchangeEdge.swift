import Foundation
import Operation_iOS

protocol AssetsHydraExchangeEdgeProtocol {
    var routeComponent: HydraDx.RemoteSwapRoute.Component { get }
}

class AssetsHydraExchangeEdge {
    let origin: ChainAssetId
    let destination: ChainAssetId
    let remoteSwapPair: HydraDx.RemoteSwapPair
    let host: HydraSwapHostProtocol

    init(
        origin: ChainAssetId,
        destination: ChainAssetId,
        remoteSwapPair: HydraDx.RemoteSwapPair,
        host: HydraSwapHostProtocol
    ) {
        self.origin = origin
        self.destination = destination
        self.remoteSwapPair = remoteSwapPair
        self.host = host
    }
}
