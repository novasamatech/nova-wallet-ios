import Foundation

struct OperationSwapViewModel {
    let direction: AssetConversion.Direction
    let assetIn: SwapAssetAmountViewModel
    let assetOut: SwapAssetAmountViewModel
    let rate: String
    let fee: BalanceViewModelProtocol
    let wallet: WalletAccountViewModel
    let transactionHash: String
}
