import Foundation

struct AssetExchangeAtomicOperationArgs {
    let swapLimit: AssetExchangeSwapLimit

    // TODO: Currently nil means native asset due to interface we have for custom fee. Better make implicit typing
    let feeAsset: ChainAssetId?
}
