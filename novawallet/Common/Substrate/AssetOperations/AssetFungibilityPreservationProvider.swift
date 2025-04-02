import Foundation

protocol AssetFungibilityPreservationProviding {
    func requiresPreservationForCrosschain(assetIn: ChainAsset) -> Bool
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
    func requiresPreservationForCrosschain(assetIn: ChainAsset) -> Bool {
        allAssets.contains(assetIn.chain.chainId) || concreteAssets.contains(assetIn.chainAssetId)
    }
}

extension AssetFungibilityPreservationProvider {
    static func createFromKnownChains() -> AssetFungibilityPreservationProvider {
        AssetFungibilityPreservationProvider(
            allAssets: [],
            concreteAssets: []
        )
    }
}
