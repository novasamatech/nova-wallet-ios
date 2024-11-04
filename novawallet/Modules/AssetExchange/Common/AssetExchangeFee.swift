import Foundation

struct AssetExchangeFee {
    let route: AssetExchangeRoute
    let fees: [AssetExchangeOperationFee]
    let slippage: BigRational
    let feeAssetId: ChainAssetId?
}
