import Foundation

#if DEBUG
    extension BittensorApiFixtureMode {
        static func applyingSubtensorStaking(
            to assets: [AssetModel],
            chainId: ChainModel.Id,
            isEnabled: Bool = BittensorApiFixtureMode.isEnabled
        ) -> [AssetModel] {
            guard isEnabled, chainId == KnowChainId.bittensor else {
                return assets
            }

            return assets.map { asset in
                guard asset.assetId == AssetModel.utilityAssetId, !asset.hasSubtensorStaking else {
                    return asset
                }

                return AssetModel(
                    assetId: asset.assetId,
                    icon: asset.icon,
                    name: asset.name,
                    symbol: asset.symbol,
                    precision: asset.precision,
                    priceId: asset.priceId,
                    stakings: (asset.stakings ?? []) + [.subtensor],
                    type: asset.type,
                    typeExtras: asset.typeExtras,
                    buyProviders: asset.buyProviders,
                    sellProviders: asset.sellProviders,
                    source: asset.source
                )
            }
        }
    }
#endif
