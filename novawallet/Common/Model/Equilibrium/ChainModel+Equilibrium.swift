import Foundation
import BigInt

extension AssetModel {
    var isEquilibriumAsset: Bool {
        type == AssetType.equilibrium.rawValue
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
