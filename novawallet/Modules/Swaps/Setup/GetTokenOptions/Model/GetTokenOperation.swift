import Foundation
import UIKit

enum GetTokenOperation {
    case crosschain
    case receive
    case buy
}

extension GetTokenOperation {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .crosschain:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositByCrossChainTransferTitle()
        case .receive:
            return R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetReceive()
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetBuy()
        }
    }

    func subtitleForLocale(_ locale: Locale, token: String) -> String {
        switch self {
        case .crosschain:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositByCrossChainTransferSubtitle(token)
        case .receive:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositByReceiveSubtitle(token)
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositByBuySubtitle(token)
        }
    }

    var icon: UIImage? {
        switch self {
        case .crosschain:
            return R.image.iconCrossChainTransfer()
        case .receive:
            return R.image.iconReceive()
        case .buy:
            return R.image.iconBuy()
        }
    }
}
