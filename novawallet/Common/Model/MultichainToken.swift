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

    var enabled: Bool {
        instances.contains { $0.enabled }
    }

    func enabledInstances() -> [Instance] {
        instances.filter { $0.enabled }
    }
}

extension MultichainToken.Instance {
    func byChangingEnabled(_ enabled: Bool) -> MultichainToken.Instance {
        .init(chainAssetId: chainAssetId, chainName: chainName, enabled: enabled, icon: icon)
    }
}

extension MultichainToken {
    func byChangingEnabled(_ enabled: Bool, for chainAssetId: ChainAssetId? = nil) -> MultichainToken {
        let newInstances = instances.map { instance in
            if chainAssetId == nil || chainAssetId == instance.chainAssetId {
                return instance.byChangingEnabled(enabled)
            } else {
                return instance
            }
        }

        return .init(symbol: symbol, instances: newInstances)
    }
}

extension Array where Element == ChainModel {
    func createMultichainTokens() -> [MultichainToken] {
        let mapping = reduce(into: [String: MultichainToken]()) { accum, chain in
            let assets = chain.assets.sorted { $0.assetId < $1.assetId }
            for asset in assets {
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

        let chainOrders = enumerated().reduce(into: [ChainModel.Id: Int]()) { accum, chainOrder in
            accum[chainOrder.1.chainId] = chainOrder.0
        }

        return mapping.values.sorted { token1, token2 in
            guard
                let chainAssetId1 = token1.instances.first?.chainAssetId,
                let chainAssetId2 = token2.instances.first?.chainAssetId else {
                return true
            }

            let order1 = chainOrders[chainAssetId1.chainId] ?? Int.max
            let order2 = chainOrders[chainAssetId2.chainId] ?? Int.max

            if order1 != order2 {
                return order1 < order2
            } else {
                return chainAssetId1.assetId < chainAssetId2.assetId
            }
        }
    }
}
