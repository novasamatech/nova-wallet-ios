import Foundation
import Operation_iOS

struct AssetVisibilityLocal: Equatable {
    let metaId: MetaAccountModel.Id
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
    let state: AssetVisibilityState

    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chainId, assetId: assetId)
    }
}

extension AssetVisibilityLocal: Identifiable {
    static func identifier(
        metaId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> String {
        [
            metaId,
            chainAssetId.chainId,
            String(chainAssetId.assetId)
        ].joined(with: .dash)
    }

    var identifier: String {
        Self.identifier(
            metaId: metaId,
            chainAssetId: chainAssetId
        )
    }
}
