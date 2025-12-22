import Foundation
@testable import novawallet

final class CurrencyManagerStub: CurrencyManagerProtocol {
    var selectedCurrency: Currency = .usd
    var availableCurrencies: [Currency] = [.usd]

    func addObserver(with _: AnyObject, queue _: DispatchQueue?, closure _: @escaping (Currency, Currency) -> Void) {}

    func addObserver(with _: AnyObject, closure _: @escaping (Currency, Currency) -> Void) {}

    func removeObserver(by _: AnyObject) {}
}
