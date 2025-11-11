import Foundation
import Operation_iOS

struct ChainAsset: Equatable, Hashable {
    let chain: ChainModel
    let asset: AssetModel
}

struct ChainAssetId: Equatable, Codable, Hashable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id

    var stringValue: String { "\(chainId)-\(assetId)" }
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
    }

    var chainAssetName: String {
        asset.name ?? chain.name
    }

    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var chainAssetInfo: ChainAssetDisplayInfo {
        ChainAssetDisplayInfo(
            asset: assetDisplayInfo,
            chain: chain.chainFormat
        )
    }

    var isUtilityAsset: Bool {
        chain.utilityAsset()?.assetId == asset.assetId
    }
}

extension ChainAssetId {
    init?(walletId: String) {
        let components = walletId.split(separator: "-")

        guard components.count == 2 else {
            return nil
        }

        guard let assetId = AssetModel.Id(String(components[1])) else {
            return nil
        }

        chainId = String(components[0])
        self.assetId = assetId
    }

    var walletId: String { chainId + "-" + String(assetId) }
}

extension ChainAsset: Identifiable {
    var identifier: String { chainAssetId.stringValue }
}
