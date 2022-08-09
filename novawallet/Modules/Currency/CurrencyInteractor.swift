import UIKit
import RobinHood

final class CurrencyInteractor {
    weak var presenter: CurrencyInteractorOutputProtocol!
    private let operationQueue: OperationQueue

    init(
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }
}

// MARK: - CurrencyInteractorInputProtocol

extension CurrencyInteractor: CurrencyInteractorInputProtocol {
    func setup() {
        guard let currencyManager = currencyManager else {
            return
        }
        presenter.didReceive(currencies: currencyManager.availableCurrencies)
        presenter.didReceive(selectedCurrency: currencyManager.selectedCurrency)
    }

    func set(selectedCurrency: Currency) {
        currencyManager?.selectedCurrency = selectedCurrency
    }
}

extension CurrencyInteractor: CurrencyDependent {
    func applyCurrencyChanges() {
        guard let currencyManager = currencyManager else {
            return
        }
        presenter?.didReceive(selectedCurrency: currencyManager.selectedCurrency)
    }
}
