import Foundation
import RobinHood
import Rswift

protocol CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]>
}
