import Foundation

struct AssetExchangeFeeSupport {
    let supportedAssets: Set<ChainAssetId>
}

extension AssetExchangeFeeSupport: AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool {
        supportedAssets.contains(chainAsset.chainAssetId)
    }
}
