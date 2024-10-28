import Foundation

struct AssetExchangeRoute {
    let items: [AssetExchangeRouteItem]
}

struct AssetExchangeRouteItem {
    let edge: AnyAssetExchangeEdge
    let amount: Balance
    let quote: Balance
    let direction: AssetConversion.Direction
}
