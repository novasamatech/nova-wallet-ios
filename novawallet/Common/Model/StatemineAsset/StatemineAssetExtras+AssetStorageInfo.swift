import Foundation

extension StatemineAssetExtras {
    init(info: AssetsPalletStorageInfo) {
        assetId = info.assetIdString
        palletName = info.palletName
    }
}
