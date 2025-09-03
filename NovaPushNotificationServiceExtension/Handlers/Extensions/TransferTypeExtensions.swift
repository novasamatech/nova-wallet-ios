import Foundation

extension PushNotification.TransferType {
    func title(locale: Locale, walletName: String?) -> String {
        let walletString = walletName.flatMap { "[\($0)]" } ?? ""
        let title: String
        switch self {
        case .income:
            title = R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReceiveTokensTitle()
        case .outcome:
            title = R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationSentTokensTitle()
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
            return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationReceiveTokensSubtitle(
                amount,
                priceString,
                chainName
            )
        case .outcome:
            if let address = address {
                return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationSentTokensSubtitle(
                    amount,
                    priceString,
                    address,
                    chainName
                )
            } else {
                return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationSentTokensNoAddressSubtitle(
                    amount,
                    priceString,
                    chainName
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
