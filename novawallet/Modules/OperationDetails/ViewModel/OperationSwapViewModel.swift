import Foundation

struct OperationSwapViewModel {
    let isOutgoing: Bool
    let assetIn: SwapAssetAmountViewModel
    let assetOut: SwapAssetAmountViewModel
    let rate: String
    let fee: BalanceViewModelProtocol
    let wallet: WalletAccountViewModel
    let transactionHash: String
}
