import Foundation

extension HydraDx {
    struct SwapRoute<Asset: Codable>: Codable {
        enum ComponentType: Codable {
            case omnipool
            case stableswap(Asset)
            case xyk
            case aave
        }

        struct Component: Codable {
            let assetIn: Asset
            let assetOut: Asset
            let type: ComponentType
        }

        let components: [Component]

        func map<T>(closure: (Asset) throws -> T) throws -> SwapRoute<T> {
            let newComponents: [SwapRoute<T>.Component] = try components.map { component in
                let newAssetIn = try closure(component.assetIn)
                let newAssetOut = try closure(component.assetOut)

                switch component.type {
                case .omnipool:
                    return SwapRoute<T>.Component(assetIn: newAssetIn, assetOut: newAssetOut, type: .omnipool)
                case let .stableswap(poolAsset):
                    let newPoolAsset = try closure(poolAsset)

                    return SwapRoute<T>.Component(
                        assetIn: newAssetIn,
                        assetOut: newAssetOut,
                        type: .stableswap(newPoolAsset)
                    )
                case .xyk:
                    return SwapRoute<T>.Component(
                        assetIn: newAssetIn,
                        assetOut: newAssetOut,
                        type: .xyk
                    )
                case .aave:
                    return SwapRoute<T>.Component(
                        assetIn: newAssetIn,
                        assetOut: newAssetOut,
                        type: .aave
                    )
                }
            }

            return SwapRoute<T>(components: newComponents)
        }
    }

    typealias LocalSwapRoute = SwapRoute<ChainAssetId>
    typealias RemoteSwapRoute = SwapRoute<HydraDx.AssetId>
}

extension HydraDx.SwapRoute.ComponentType: Equatable & Hashable where Asset: Equatable & Hashable {}
extension HydraDx.SwapRoute.Component: Equatable & Hashable where Asset: Equatable & Hashable {}
