import Foundation

struct AssetExchangeFeeSupport {
    let supportedAssets: Set<ChainAssetId>
}

extension AssetExchangeFeeSupport: AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool {
        supportedAssets.contains(chainAsset.chainAssetId)
    }
}

struct CompoundAssetExchangeFeeSupport {
    let supporters: [AssetExchangeFeeSupporting]
}

extension CompoundAssetExchangeFeeSupport: AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool {
        supporters.contains { $0.canPayFee(inNonNative: chainAsset) }
    }
}
