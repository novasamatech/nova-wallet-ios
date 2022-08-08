import UIKit
import RobinHood

final class CurrencyInteractor {
    weak var presenter: CurrencyInteractorOutputProtocol!
    private let currencyRepository: CurrencyRepositoryProtocol
    private let userCurrencyRepository: UserCurrencyRepositoryProtocol
    private let operationQueue: OperationQueue

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
                do {
                    let currencies = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didRecieve(currencies: currencies)
                } catch {
                    self?.presenter.didRecieve(error: error)
                }
            }
        }

        return wrapper
    }

    private func selectedCurrencyOperationWrapper() -> CompoundOperationWrapper<Currency?> {
        let wrapper = userCurrencyRepository.selectedCurrency()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    if let selectedCurrency = try wrapper.targetOperation.extractNoCancellableResultData() {
                        self?.presenter.didRecieve(selectedCurrency: selectedCurrency)
                    }
                } catch {
                    self?.presenter.didRecieve(error: error)
                }
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

    func set(selectedCurrency: Currency) {
        userCurrencyRepository.setSelectedCurrency(selectedCurrency)
        presenter.didRecieve(selectedCurrency: selectedCurrency)
    }
}
