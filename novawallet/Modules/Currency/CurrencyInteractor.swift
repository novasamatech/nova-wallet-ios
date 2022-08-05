import UIKit
import RobinHood

final class CurrencyInteractor {
    weak var presenter: CurrencyInteractorOutputProtocol!
    private let currencyRepository: CurrencyRepositoryProtocol
    private let userCurrencyRepository: UserCurrencyRepositoryProtocol
    private let operationQueue: OperationQueue
    private var currencies: [Currency] = []

    init(
        currencyRepository: CurrencyRepositoryProtocol,
        userCurrencyRepository: UserCurrencyRepositoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.currencyRepository = currencyRepository
        self.userCurrencyRepository = userCurrencyRepository
        self.operationQueue = operationQueue
    }

    private func allCurrenciesOperationWrapper() -> CompoundOperationWrapper<[Currency]> {
        let wrapper = currencyRepository.fetchAvailableCurrenciesWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let currencies = try? wrapper.targetOperation.extractNoCancellableResultData() else {
                    return
                }
                self?.currencies = currencies
                self?.presenter.didRecieve(currencies: currencies)
            }
        }

        return wrapper
    }

    private func selectedCurrencyOperationWrapper() -> CompoundOperationWrapper<Currency?> {
        let wrapper = userCurrencyRepository.selectedCurrency()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let currency = try? wrapper.targetOperation.extractNoCancellableResultData() else {
                    return
                }
                self?.presenter.didRecieve(selectedCurrency: currency)
            }
        }

        return wrapper
    }
}

// MARK: - CurrencyInteractorInputProtocol

extension CurrencyInteractor: CurrencyInteractorInputProtocol {
    func setup() {
        let fetchCurrenciesOperations = allCurrenciesOperationWrapper()
        let selectedCurrencyOperation = selectedCurrencyOperationWrapper()
        operationQueue.addOperations(
            fetchCurrenciesOperations.allOperations +
                selectedCurrencyOperation.allOperations,
            waitUntilFinished: false
        )
    }

    func set(selectedCurrencyId: Int) {
        guard let selectedCurrency = currencies.first(where: { $0.id == selectedCurrencyId }) else {
            return
        }
        let operation = userCurrencyRepository.setSelectedCurrency(selectedCurrency)
        operation.completionBlock = { [weak self, selectedCurrency] in
            self?.presenter?.didRecieve(selectedCurrency: selectedCurrency)
        }
        operationQueue.addOperation(operation)
    }
}
