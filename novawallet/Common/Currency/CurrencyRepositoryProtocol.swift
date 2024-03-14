import Foundation
import RobinHood

protocol CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]>
}
