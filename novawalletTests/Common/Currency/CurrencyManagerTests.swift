import XCTest
import Cuckoo
import Operation_iOS
import Keystore_iOS
@testable import novawallet

final class CurrencyManagerTests: XCTestCase {
    private let settingsManager: SettingsManagerProtocol = InMemorySettingsManager()

    override func setUp() {
        settingsManager.removeAll()
    }

    func testDefaultValue() throws {
        let currencyManager = try createCurrencyManager(currencies: [.usd, .btc])
        XCTAssertEqual(currencyManager.selectedCurrency.id, Currency.usd.id)
    }

    func testSaveSelectedCurrency() throws {
        let currencyManager = try createCurrencyManager(currencies: [.usd, .btc])
        currencyManager.selectedCurrency = .btc

        XCTAssertEqual(settingsManager.selectedCurrencyId, Currency.btc.id)
    }

    func testGetSelectedCurrency() throws {
        settingsManager.selectedCurrencyId = Currency.btc.id
        let currencyManager = try createCurrencyManager(currencies: [.usd, .btc])

        XCTAssertEqual(currencyManager.selectedCurrency, Currency.btc)
    }

    func testSelectedCurrencyNotification() throws {
        let expectation = XCTestExpectation(description: "Change selected currency expectation")
        let currencyManager = try createCurrencyManager(currencies: [.usd, .btc])

        currencyManager.addObserver(with: self) { _, newValue in
            XCTAssertEqual(newValue, Currency.btc)
            expectation.fulfill()
        }
        currencyManager.selectedCurrency = Currency.btc
        wait(for: [expectation], timeout: 5)

        currencyManager.removeObserver(by: self)
    }

    func testEmptyListError() {
        XCTAssertThrowsError(try createCurrencyManager(currencies: []))
    }

    private func createCurrencyManager(currencies: [Currency]) throws -> CurrencyManagerProtocol {
        let currencyRepository = createCurrencyRepository(currencies: currencies)
        let currencyManager = try CurrencyManager(
            currencyRepository: currencyRepository,
            settingsManager: settingsManager,
            queue: .init()
        )
        return currencyManager
    }

    private func createCurrencyRepository(currencies: [Currency]) -> CurrencyRepositoryProtocol {
        let repository = MockCurrencyRepositoryProtocol()
        stub(repository) { stub in
            stub.fetchAvailableCurrenciesWrapper().then {
                CompoundOperationWrapper.createWithResult(currencies)
            }
        }
        return repository
    }
}
