import Foundation

protocol CurrencyDependent: AnyObject {
    var currencyManager: CurrencyManagerProtocol? { get set }

    func applyCurrencyChanges()
}

private enum CurrencyDependentConstants {
    static var managerKey = "co.jp.novawallet.currencyDependent.manager"
}

extension CurrencyDependent {
    var currencyManager: CurrencyManagerProtocol? {
        get {
            objc_getAssociatedObject(self, &CurrencyDependentConstants.managerKey)
                as? CurrencyManagerProtocol
        }

        set {
            let currentManager = currencyManager

            guard newValue !== currentManager else {
                return
            }

            currentManager?.removeObserver(by: self)

            newValue?.addObserver(with: self) { [weak self] _, _ in
                self?.applyCurrencyChanges()
            }

            objc_setAssociatedObject(
                self,
                &CurrencyDependentConstants.managerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )

            applyCurrencyChanges()
        }
    }
}
