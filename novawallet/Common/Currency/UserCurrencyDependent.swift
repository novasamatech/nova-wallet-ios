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
