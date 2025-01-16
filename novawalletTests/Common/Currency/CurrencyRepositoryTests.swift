import XCTest
import Cuckoo
import Operation_iOS
import Keystore_iOS
@testable import novawallet

final class CurrencyRepositoryTests: XCTestCase {
  
    func testFetchAvailableCurrencies() throws {
        let currencyRepository = CurrencyRepository()
        let queue = OperationQueue()
        let availableCurrenciesWrapper = currencyRepository.fetchAvailableCurrenciesWrapper()
        queue.addOperations(availableCurrenciesWrapper.allOperations, waitUntilFinished: true)
        let currencies = try availableCurrenciesWrapper.targetOperation.extractResultData()
        XCTAssertNotNil(currencies)
        XCTAssertFalse(currencies!.isEmpty)
    }
    
    func testParsingCurrencyJson() throws {
        let currencyRepository = CurrencyRepository()
        let queue = OperationQueue()
        let operation: BaseOperation<[Currency]> = currencyRepository.fetchOperation(by: json("currencies"), defaultValue: [])
        queue.addOperations([operation], waitUntilFinished: true)
        let currencies = try operation.extractResultData() ?? []
        XCTAssertFalse(currencies.isEmpty)
       
        let currency = currencies[0]
        XCTAssertEqual(currency.id, 0)
        XCTAssertEqual(currency.code, "USD")
        XCTAssertEqual(currency.name, "United States Dollar")
        XCTAssertEqual(currency.symbol, "$")
        XCTAssertEqual(currency.category, .fiat)
        XCTAssertEqual(currency.isPopular, true)
        XCTAssertEqual(currency.coingeckoId, "usd")
    }
    
    private func json(_ name: String) -> URL? {
        guard let path = Bundle(for: CurrencyRepositoryTests.self).path(forResource: name, ofType: "json") else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
