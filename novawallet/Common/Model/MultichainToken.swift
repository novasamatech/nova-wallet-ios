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
    func byChanging(enabled: Bool) -> MultichainToken.Instance {
        .init(chainAssetId: chainAssetId, chainName: chainName, enabled: enabled, icon: icon)
    }
}

extension MultichainToken {
    func byChanging(enabled: Bool, for chainAssetId: ChainAssetId? = nil) -> MultichainToken {
        let newInstances = instances.map { instance in
            if chainAssetId == nil || chainAssetId == instance.chainAssetId {
                return instance.byChanging(enabled: enabled)
            } else {
                return instance
            }
        }

        return .init(symbol: symbol, instances: newInstances)
    }
}

extension Array where Element == ChainModel {
    func createMultichainToken(for symbol: String) -> MultichainToken {
        reduce(MultichainToken(symbol: symbol, instances: [])) { token, chain in
            let assets = chain.assets.filter {
                MultichainToken.reserveTokensOf(symbol: $0.symbol).contains(symbol)
            }.sorted { $0.assetId < $1.assetId }

            return assets.reduce(token) { _, asset in
                let instance = MultichainToken.Instance(
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                    chainName: chain.name,
                    enabled: asset.enabled,
                    icon: asset.icon
                )

                return MultichainToken(symbol: symbol, instances: token.instances + [instance])
            }
        }
    }

    func createMultichainTokens() -> [MultichainToken] {
        let mapping = createMultichainTokenMapping()

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

    private func createMultichainTokenMapping() -> [String: MultichainToken] {
        let allSymbols = reduce(into: Set<String>()) { accum, chain in
            for asset in chain.assets {
                accum.insert(asset.symbol)
            }
        }

        return reduce(into: [String: MultichainToken]()) { accum, chain in
            let assets = chain.assets.sorted { $0.assetId < $1.assetId }
            for asset in assets {
                let instance = MultichainToken.Instance(
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                    chainName: chain.name,
                    enabled: asset.enabled,
                    icon: asset.icon
                )

                let symbolExtensions = MultichainToken.reserveTokensOf(symbol: asset.symbol)
                let tokenSymbol = symbolExtensions.first(where: { allSymbols.contains($0) }) ?? asset.symbol

                if let token = accum[tokenSymbol] {
                    accum[tokenSymbol] = MultichainToken(
                        symbol: tokenSymbol,
                        instances: token.instances + [instance]
                    )
                } else {
                    accum[tokenSymbol] = MultichainToken(
                        symbol: tokenSymbol,
                        instances: [instance]
                    )
                }
            }
        }
    }
}

extension MultichainToken {
    static func reserveTokensOf(symbol: String) -> [String] {
        let xcExtension = "xc"

        if symbol.hasPrefix(xcExtension) {
            let newSymbol = String(symbol.suffix(symbol.count - xcExtension.count))
            return [newSymbol, symbol]
        } else {
            return [symbol]
        }
    }
}
