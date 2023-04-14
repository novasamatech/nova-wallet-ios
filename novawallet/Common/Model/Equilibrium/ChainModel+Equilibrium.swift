import Foundation
import BigInt

extension AssetModel {
    var isEquilibriumAsset: Bool {
        type == AssetType.equilibrium.rawValue
    }

    var equilibriumAssetId: AssetModel.Id? {
        guard let assetId = try? typeExtras?.map(to: StatemineAssetExtras.self).assetId else {
            return nil
        }
        return AssetModel.Id(assetId)
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
