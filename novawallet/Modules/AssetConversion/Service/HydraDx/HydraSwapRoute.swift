import Foundation

extension HydraDx {
    struct SwapRoute<Asset> {
        enum ComponentType {
            case omnipool
            case stableswap(Asset)
        }
        
        struct Component {
            let assetIn: Asset
            let assetOut: Asset
            let type: ComponentType
        }
        
        let components: [Component]
    }
}
