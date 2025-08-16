import Foundation

protocol AssetFungibilityPreservationProviding {
    func requiresPreservationForCrosschain(
        assetIn: ChainAsset,
        metadata: XcmTransferMetadata
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
        assetIn: ChainAsset,
        metadata: XcmTransferMetadata
    ) -> Bool {
        // xcm execute allows to bypass keep alive requirements
        guard !metadata.supportsXcmExecute else {
            return false
        }

        let requiresKeepAlive = allAssets.contains(assetIn.chain.chainId) ||
            concreteAssets.contains(assetIn.chainAssetId)

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
