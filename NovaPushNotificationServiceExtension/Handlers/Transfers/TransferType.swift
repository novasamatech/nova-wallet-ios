import Foundation

enum TransferType {
    case income
    case outcome

    func title(locale: Locale) -> String {
        switch self {
        case .income:
            return localizedString(LocalizationKeys.Transfer.incomeTitle, locale: locale)
        case .outcome:
            return localizedString(LocalizationKeys.Transfer.outcomeTitle, locale: locale)
        }
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
