import UIKit

final class CurrencyInteractor {
    weak var presenter: CurrencyInteractorOutputProtocol!
    private let repository: CurrencyRepositoryProtocol
    private let operationQueue: OperationQueue

    init(
        repository: CurrencyRepositoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
    }

    private func fetchAllCurrencies() {
        let wrapper = repository.fetchAvailableCurrenciesWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let currencies = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didRecieve(currencies: currencies ?? [])
                } catch {
                    print(error.localizedDescription)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension CurrencyInteractor: CurrencyInteractorInputProtocol {
    func fetchCurrencies() {
        fetchAllCurrencies()
    }
}
