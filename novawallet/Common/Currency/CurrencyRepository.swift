import Foundation
import RobinHood

protocol CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]>
}

final class CurrencyRepository: JsonFileRepository<[Currency]> {
    static let shared = CurrencyRepository()

    @Atomic(defaultValue: [])
    private var currencies: [Currency]
}

extension CurrencyRepository: CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]> {
        guard currencies.isEmpty else {
            return CompoundOperationWrapper.createWithResult(currencies)
        }
        let fetchCurrenciesOperation = fetchOperation(
            by: R.file.currenciesJson(),
            defaultValue: []
        )
        let cacheOperation: BaseOperation<[Currency]> = ClosureOperation { [weak self] in
            let currencies = try fetchCurrenciesOperation.extractNoCancellableResultData()
            self?.currencies = currencies
            return currencies
        }
        cacheOperation.addDependency(fetchCurrenciesOperation)

        return CompoundOperationWrapper(
            targetOperation: cacheOperation,
            dependencies: [fetchCurrenciesOperation]
        )
    }
}
