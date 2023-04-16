import Foundation
import BigInt

extension AssetModel {
    var isEquilibriumAsset: Bool {
        type == AssetType.equilibrium.rawValue
    }

    var equilibriumAssetId: UInt64? {
        guard isEquilibriumAsset, let assetId = try? typeExtras?.map(to: EquilibriumAssetExtras.self).assetId else {
            return nil
        }
        return assetId
    }
}

extension ChainModel {
    var hasEquilibriumAsset: Bool {
        assets.contains { $0.isEquilibriumAsset }
    }

    var equilibriumAssets: Set<AssetModel> {
        assets.filter { $0.isEquilibriumAsset }
    }
}
