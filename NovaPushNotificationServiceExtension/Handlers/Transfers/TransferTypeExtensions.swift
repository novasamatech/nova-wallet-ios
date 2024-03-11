import Foundation

extension TransferType {
    func title(locale: Locale, walletName: String?) -> String {
        let walletString = walletName.flatMap { "[\($0)]" } ?? ""
        let title: String
        switch self {
        case .income:
            title = localizedString(LocalizationKeys.Transfer.incomeTitle, locale: locale)
        case .outcome:
            title = localizedString(LocalizationKeys.Transfer.outcomeTitle, locale: locale)
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
            return localizedString(
                LocalizationKeys.Transfer.incomeSubtitle,
                with: [amount, priceString, chainName],
                locale: locale
            )
        case .outcome:
            if let address = address {
                return localizedString(
                    LocalizationKeys.Transfer.outcomeSubtitle,
                    with: [amount, priceString, address, chainName],
                    locale: locale
                )
            } else {
                return localizedString(
                    LocalizationKeys.Transfer.outcomeWOAddressSubtitle,
                    with: [amount, priceString, chainName],
                    locale: locale
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
