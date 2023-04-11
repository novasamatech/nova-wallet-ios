import Foundation
import BigInt

extension AssetModel {
    var isEquilibriumAsset: Bool {
        false
        // TODO:
        // type == AssetType.equilibriumAsset.rawValue
    }
}

extension ChainModel {
    var hasEquilibriumAsset: Bool {
        assets.contains { $0.isEquilibriumAsset }
    }
}
