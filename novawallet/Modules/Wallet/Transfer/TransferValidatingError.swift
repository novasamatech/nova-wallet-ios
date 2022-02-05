import Foundation
import CommonWallet

enum NovaTransferValidatingError: Error {
    case receiverBalanceTooLow
    case cantPayFee
    case noReceiverAccount(assetSymbol: String)
}

extension NovaTransferValidatingError: WalletErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> WalletErrorContentProtocol {
        let title: String
        let message: String

        switch self {
        case .receiverBalanceTooLow:
            title = R.string.localizable
                .walletSendDeadRecipientTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .walletSendDeadRecipientMessage(preferredLanguages: locale?.rLanguages)
        case .cantPayFee:
            title = R.string.localizable
                .walletSendDeadRecipientTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .walletFeeOverExistentialDeposit(preferredLanguages: locale?.rLanguages)
        case let .noReceiverAccount(assetSymbol):
            title = R.string.localizable.walletSendDeadRecipientCommissionAssetTitle(
                preferredLanguages: locale?.rLanguages
            )

            message = R.string.localizable.walletSendDeadRecipientCommissionAssetMessage(
                assetSymbol,
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
