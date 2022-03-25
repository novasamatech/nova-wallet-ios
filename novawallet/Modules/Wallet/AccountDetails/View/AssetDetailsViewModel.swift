import Foundation
import CommonWallet

final class AssetDetailsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = ""
    var itemHeight: CGFloat = 0.0
    var command: WalletCommandProtocol? { nil }

    let price: String
    let priceChangeViewModel: WalletPriceChangeViewModel

    let totalBalance: BalanceViewModel
    let transferableBalance: BalanceViewModel
    let lockedBalance: BalanceViewModel

    let networkName: String
    let networkIcon: ImageViewModelProtocol

    let infoDetailsCommand: WalletCommandProtocol

    init(
        price: String,
        priceChangeViewModel: WalletPriceChangeViewModel,
        totalBalance: BalanceViewModel,
        transferableBalance: BalanceViewModel,
        lockedBalance: BalanceViewModel,
        networkName: String,
        networkIcon: ImageViewModelProtocol,
        infoDetailsCommand: WalletCommandProtocol
    ) {
        self.price = price
        self.priceChangeViewModel = priceChangeViewModel
        self.totalBalance = totalBalance
        self.transferableBalance = transferableBalance
        self.lockedBalance = lockedBalance
        self.networkName = networkName
        self.networkIcon = networkIcon
        self.infoDetailsCommand = infoDetailsCommand
    }
}
