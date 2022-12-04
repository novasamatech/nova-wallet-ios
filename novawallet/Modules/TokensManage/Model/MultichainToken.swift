import Foundation

struct MultichainToken {
    struct Instance {
        let chainAssetId: ChainAssetId
        let chainName: String
        let enabled: Bool
        let icon: URL?
    }

    let symbol: String
    let instances: [Instance]

    var icon: URL? {
        instances.first(where: { $0.icon != nil })?.icon
    }
}

extension Array where Element == ChainModel {
    func createMultichainTokens() -> [MultichainToken] {
        let mapping = reduce(into: [String: MultichainToken]()) { (accum, chain) in
            for asset in chain.assets {
                let instance = MultichainToken.Instance(
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                    chainName: chain.name,
                    enabled: asset.enabled,
                    icon: asset.icon
                )

                if let token = accum[asset.symbol] {
                    accum[asset.symbol] = MultichainToken(
                        symbol: asset.symbol,
                        instances: token.instances + [instance]
                    )
                } else {
                    accum[asset.symbol] = MultichainToken(
                        symbol: asset.symbol,
                        instances: [instance]
                    )
                }
            }
        }

        let chainOrders = enumerated().reduce(into: [ChainModel.Id: Int]()) { (accum, chainOrder) in
            accum[chainOrder.1.chainId] = chainOrder.0
        }

        return mapping.values.sorted { token1, token2 in
            guard
                let chainId1 = token1.instances.first?.chainAssetId.chainId,
                let chainId2 = token2.instances.first?.chainAssetId.chainId else {
                return true
            }

            let order1 = chainOrders[chainId1] ?? Int.max
            let order2 = chainOrders[chainId2] ?? Int.max

            return order1 < order2
        }
    }
}
