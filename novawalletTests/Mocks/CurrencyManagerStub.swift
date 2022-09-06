import Foundation
@testable import novawallet

final class CurrencyManagerStub: CurrencyManagerProtocol {
    var selectedCurrency: Currency = .usd
    var availableCurrencies: [Currency] = [.usd]
    
    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping (Currency, Currency) -> Void) {
    }
    
    func addObserver(with owner: AnyObject, closure: @escaping (Currency, Currency) -> Void) {
    }
    
    func removeObserver(by owner: AnyObject) {
    }
    
}
