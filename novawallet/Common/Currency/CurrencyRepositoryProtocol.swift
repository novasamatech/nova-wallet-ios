import Foundation
import Operation_iOS

protocol CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]>
}
