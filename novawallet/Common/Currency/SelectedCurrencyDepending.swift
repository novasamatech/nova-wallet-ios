import Foundation

protocol SelectedCurrencyDepending: AnyObject {
    var currencyManager: CurrencyManagerProtocol? { get set }

    func applyCurrency()
}

private enum SelectedCurrencyDependingConstants {
    static var managerKey = "com.novawallet.selectedCurrencyDepending.manager"
}

extension SelectedCurrencyDepending {
    var currencyManager: CurrencyManagerProtocol? {
        get {
            objc_getAssociatedObject(self, &SelectedCurrencyDependingConstants.managerKey)
                as? CurrencyManagerProtocol
        }

        set {
            let currentManager = currencyManager

            guard newValue !== currentManager else {
                return
            }

            currentManager?.removeObserver(by: self)

            newValue?.addObserver(with: self) { [weak self] _, _ in
                self?.applyCurrency()
            }

            objc_setAssociatedObject(
                self,
                &SelectedCurrencyDependingConstants.managerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )

            applyCurrency()
        }
    }
}

extension SelectedCurrencyDepending {
    var selectedCurrency: Currency {
        guard let selectedCurrency = currencyManager?.selectedCurrency else {
            assertionFailure("Currency manager must be created")
            return .usd
        }
        return selectedCurrency
    }
}

extension Currency {
    static let usd = Currency(
        id: 0,
        code: "USD",
        name: "United States Dollar",
        symbol: "$",
        category: .fiat,
        isPopular: true,
        coingeckoId: "usd"
    )
}
