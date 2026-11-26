import Foundation

enum HydraExtrinsicConverter {
    static func isOmnipoolSwap(route: HydraDx.RemoteSwapRoute) -> Bool {
        guard route.components.count == 1 else {
            return false
        }

        if case .omnipool = route.components[0].type {
            return true
        } else {
            return false
        }
    }

    static func convertRouteToTrade(_ route: HydraDx.RemoteSwapRoute) -> [HydraRouter.Trade] {
        route.components.map { component in
            switch component.type {
            case .omnipool:
                return HydraRouter.Trade(
                    pool: .omnipool,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case let .stableswap(poolAsset):
                return HydraRouter.Trade(
                    pool: .stableswap(poolAsset),
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case .xyk:
                return HydraRouter.Trade(
                    pool: .xyk,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case .aave:
                return HydraRouter.Trade(
                    pool: .aave,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            }
        }
    }
}
