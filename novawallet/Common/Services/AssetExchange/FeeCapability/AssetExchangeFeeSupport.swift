import Foundation

struct AssetExchangeFeeSupport {
    let supportedAssets: Set<ChainAssetId>
}

extension AssetExchangeFeeSupport: AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAssetId: ChainAssetId) -> Bool {
        supportedAssets.contains(chainAssetId)
    }
}

struct CompoundAssetExchangeFeeSupport {
    let supporters: [AssetExchangeFeeSupporting]
}

extension CompoundAssetExchangeFeeSupport: AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAssetId: ChainAssetId) -> Bool {
        supporters.contains { $0.canPayFee(inNonNative: chainAssetId) }
    }
}
