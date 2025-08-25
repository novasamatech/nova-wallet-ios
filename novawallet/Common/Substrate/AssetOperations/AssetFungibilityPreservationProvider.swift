import Foundation

protocol AssetFungibilityPreservationProviding {
    func requiresPreservationForCrosschain(
        assetIn: ChainAssetId,
        features: XcmTransferFeatures
    ) -> Bool
}

final class AssetFungibilityPreservationProvider {
    let allAssets: Set<ChainModel.Id>
    let concreteAssets: Set<ChainAssetId>

    init(allAssets: Set<ChainModel.Id>, concreteAssets: Set<ChainAssetId>) {
        self.allAssets = allAssets
        self.concreteAssets = concreteAssets
    }
}

extension AssetFungibilityPreservationProvider: AssetFungibilityPreservationProviding {
    func requiresPreservationForCrosschain(
        assetIn: ChainAssetId,
        features: XcmTransferFeatures
    ) -> Bool {
        // xcm execute allows to bypass keep alive requirements
        guard !features.shouldUseXcmExecute else {
            return false
        }

        let requiresKeepAlive = allAssets.contains(assetIn.chainId) ||
            concreteAssets.contains(assetIn)

        return requiresKeepAlive
    }
}

extension AssetFungibilityPreservationProvider {
    static func createFromKnownChains() -> AssetFungibilityPreservationProvider {
        AssetFungibilityPreservationProvider(
            allAssets: [
                KnowChainId.polkadotAssetHub,
                KnowChainId.kusamaAssetHub
            ],
            concreteAssets: [
                ChainAssetId(
                    chainId: KnowChainId.astar,
                    assetId: AssetModel.utilityAssetId
                )
            ]
        )
    }
}
