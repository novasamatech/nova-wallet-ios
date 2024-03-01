import Foundation
import RobinHood
import Rswift

final class CurrencyRepository: JsonFileRepository<[Currency]> {
    static let shared = CurrencyRepository()
    static let fileName = "currencies"
    
    @Atomic(defaultValue: [])
    private var currencies: [Currency]
}

extension CurrencyRepository: CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]> {
        guard currencies.isEmpty else {
            return CompoundOperationWrapper.createWithResult(currencies)
        }
    
        let currenciesJson = json(Self.fileName)!
        let fetchCurrenciesOperation = fetchOperation(
            by: currenciesJson,
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
    
    private func json(_ name: String) -> URL? {
        guard let path = Bundle(for: Self.self).path(forResource: name, ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
