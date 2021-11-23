import Foundation
import CommonWallet

final class AssetDetailsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = ""
    var itemHeight: CGFloat = 0.0
    var command: WalletCommandProtocol? { nil }

    let title: String
    let imageViewModel: WalletImageViewModelProtocol?
    let price: String
    let priceChangeViewModel: WalletPriceChangeViewModel

    let balancesTitle: String

    let totalTitle: String
    let totalBalance: BalanceViewModel

    let transferableTitle: String
    let transferableBalance: BalanceViewModel

    let lockedTitle: String
    let lockedBalance: BalanceViewModel

    let infoDetailsCommand: WalletCommandProtocol

    init(
        title: String,
        imageViewModel: WalletImageViewModelProtocol?,
        price: String,
        priceChangeViewModel: WalletPriceChangeViewModel,
        balancesTitle: String,
        totalTitle: String,
        totalBalance: BalanceViewModel,
        transferableTitle: String,
        transferableBalance: BalanceViewModel,
        lockedTitle: String,
        lockedBalance: BalanceViewModel,
        infoDetailsCommand: WalletCommandProtocol
    ) {
        self.title = title
        self.imageViewModel = imageViewModel
        self.price = price
        self.priceChangeViewModel = priceChangeViewModel
        self.balancesTitle = balancesTitle
        self.totalTitle = totalTitle
        self.totalBalance = totalBalance
        self.transferableTitle = transferableTitle
        self.transferableBalance = transferableBalance
        self.lockedTitle = lockedTitle
        self.lockedBalance = lockedBalance
        self.infoDetailsCommand = infoDetailsCommand
    }
}
