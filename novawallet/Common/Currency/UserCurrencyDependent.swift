import Foundation

protocol UserCurrencyDependent: AnyObject {
    var currencyManager: CurrencyManagerProtocol? { get set }

    func applyCurrency()
}

private enum UserCurrencyDependentConstants {
    static var managerKey = "co.jp.novawallet.currencyDependent.manager"
}

extension UserCurrencyDependent {
    var currencyManager: CurrencyManagerProtocol? {
        get {
            objc_getAssociatedObject(self, &UserCurrencyDependentConstants.managerKey)
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
                &UserCurrencyDependentConstants.managerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )

            applyCurrency()
        }
    }
}
