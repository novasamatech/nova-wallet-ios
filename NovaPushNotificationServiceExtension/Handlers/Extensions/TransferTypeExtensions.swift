import Foundation

extension PushNotification.TransferType {
    func title(locale: Locale, walletName: String?) -> String {
        let walletString = walletName.flatMap { "[\($0)]" } ?? ""
        let title: String
        switch self {
        case .income:
            title = R.string.localizable.pushNotificationReceiveTokensTitle(preferredLanguages: locale.rLanguages)
        case .outcome:
            title = R.string.localizable.pushNotificationSentTokensTitle(preferredLanguages: locale.rLanguages)
        }

        return [title, walletString].joined(with: .space)
    }

    func subtitle(
        amount: String,
        price: String?,
        chainName: String,
        address: AccountAddress?,
        locale: Locale
    ) -> String {
        let priceString = price.map { "(\($0))" } ?? ""
        switch self {
        case .income:
            return R.string.localizable.pushNotificationReceiveTokensSubtitle(
                amount,
                priceString,
                chainName,
                preferredLanguages: locale.rLanguages
            )
        case .outcome:
            if let address = address {
                return R.string.localizable.pushNotificationSentTokensSubtitle(
                    amount,
                    priceString,
                    address,
                    chainName,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return R.string.localizable.pushNotificationSentTokensNoAddressSubtitle(
                    amount,
                    priceString,
                    chainName,
                    preferredLanguages: locale.rLanguages
                )
            }
        }
    }

    func address(from payload: NotificationTransferPayload) -> AccountAddress? {
        switch self {
        case .income:
            return nil
        case .outcome:
            return payload.recipient
        }
    }
}
