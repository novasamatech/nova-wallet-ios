import Foundation
import CommonWallet

final class AssetDetailsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = ""
    var itemHeight: CGFloat = 0.0
    var command: WalletCommandProtocol? { nil }

    let title: String
    let imageViewModel: WalletImageViewModelProtocol?
    let amount: String // TODO: Check if used anywhere else
    let price: String
    let priceChangeViewModel: WalletPriceChangeViewModel
    let totalVolume: String

    // FIXME: Convert according to new layout
    let leftTitle: String
    let leftDetails: String

    // FIXME: Convert according to new layout
    let rightTitle: String
    let rightDetails: String

    let infoDetailsCommand: WalletCommandProtocol

    init(
        title: String,
        imageViewModel: WalletImageViewModelProtocol?,
        amount: String,
        price: String,
        priceChangeViewModel: WalletPriceChangeViewModel,
        totalVolume: String,
        leftTitle: String,
        leftDetails: String,
        rightTitle: String,
        rightDetails: String,
        infoDetailsCommand: WalletCommandProtocol
    ) {
        self.title = title
        self.imageViewModel = imageViewModel
        self.amount = amount
        self.price = price
        self.priceChangeViewModel = priceChangeViewModel
        self.totalVolume = totalVolume
        self.leftTitle = leftTitle
        self.leftDetails = leftDetails
        self.rightTitle = rightTitle
        self.rightDetails = rightDetails
        self.infoDetailsCommand = infoDetailsCommand
    }
}
