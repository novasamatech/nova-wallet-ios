import Foundation

struct ChainAsset: Equatable {
    let chain: ChainModel
    let asset: AssetModel
}

struct ChainAssetId: Equatable, Codable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
}

extension ChainAsset {
    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
    }

    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var chainAssetInfo: ChainAssetDisplayInfo {
        ChainAssetDisplayInfo(
            asset: assetDisplayInfo,
            chain: chain.chainFormat
        )
    }
}

extension ChainAssetId {
    init?(walletId: String) {
        let components = walletId.split(separator: "-")

        guard components.count == 2 else {
            return nil
        }

        guard
            let chainIdData = try? Data(hexString: String(components[0])),
            let assetId = AssetModel.Id(String(components[1])) else {
            return nil
        }

        chainId = chainIdData.toHex()
        self.assetId = assetId
    }

    var walletId: String { chainId + "-" + String(assetId) }
}
