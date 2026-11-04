import Foundation
import UIKit

enum GetTokenOperation {
    case crosschain
    case receive
    case buy
    case changeNow
}

extension GetTokenOperation {
    private enum Constants {
        static let changeNowName = "ChangeNOW"
        static let changeNowLeadingTokens = ["DOT", "USDT"]
        static let changeNowLastToken = "USDC"
    }

    static func operations(for chainAsset: ChainAsset) -> [GetTokenOperation] {
        let operations: [GetTokenOperation] = [.crosschain, .receive, .buy]

        return supportsChangeNow(chainAsset) ? operations + [.changeNow] : operations
    }

    static func supportsChangeNow(_ chainAsset: ChainAsset) -> Bool {
        chainAsset.chain.chainId == KnowChainId.bittensor && chainAsset.isUtilityAsset
    }

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .crosschain:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByCrossChainTransferTitle()
        case .receive:
            return R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetReceive()
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetBuy()
        case .changeNow:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByDappTitle(Constants.changeNowName)
        }
    }

    func subtitleForLocale(_ locale: Locale, token: String) -> String {
        switch self {
        case .crosschain:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByCrossChainTransferSubtitle(token)
        case .receive:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByReceiveSubtitle(token)
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositByBuySubtitle(token)
        case .changeNow:
            let strings = R.string(preferredLanguages: locale.rLanguages).localizable
            let tokens = strings.swapsSetupDepositAlternatives(
                Constants.changeNowLeadingTokens.joined(with: .commaSpace),
                Constants.changeNowLastToken
            )

            return strings.swapsSetupDepositByDappSubtitle(tokens)
        }
    }

    func chipForLocale(_ locale: Locale) -> String? {
        switch self {
        case .crosschain, .receive, .buy:
            return nil
        case .changeNow:
            return R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDepositThirdParty()
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
        case .changeNow:
            return R.image.iconActionWeb()
        }
    }
}
