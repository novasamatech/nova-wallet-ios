import Foundation

protocol AssetExchangeFeeCapabilityStoring {
    func store(_ feeCapability: Set<ChainAssetId>)
}

protocol AssetExchangeFeeCapabilityProviding {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool
}

final class AssetExchangeFeeCapabilityProvider {
    @Atomic(defaultValue: [])
    var feeCapability: Set<ChainAssetId>
}

extension AssetExchangeFeeCapabilityProvider: AssetExchangeFeeCapabilityProviding {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool {
        feeCapability.contains(chainAsset.chainAssetId)
    }
}

extension AssetExchangeFeeCapabilityProvider: AssetExchangeFeeCapabilityStoring {
    func store(_ feeCapability: Set<ChainAssetId>) {
        self.feeCapability.formUnion(feeCapability)
    }
}
