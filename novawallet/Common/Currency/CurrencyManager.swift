import Foundation
import Keystore_iOS

protocol CurrencyManagerProtocol: AnyObject {
    var availableCurrencies: [Currency] { get }
    var selectedCurrency: Currency { get set }

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Currency, Currency) -> Void
    )
    func addObserver(
        with owner: AnyObject,
        closure: @escaping (Currency, Currency) -> Void
    )
    func removeObserver(by owner: AnyObject)
}

final class CurrencyManager: Observable<Currency>, CurrencyManagerProtocol {
    let availableCurrencies: [Currency]
    var selectedCurrency: Currency {
        get {
            state
        }
        set {
            state = newValue
        }
    }

    private let settingsManager: SettingsManagerProtocol

    init(
        currencyRepository: CurrencyRepositoryProtocol,
        settingsManager: SettingsManagerProtocol,
        queue: OperationQueue
    ) throws {
        self.settingsManager = settingsManager

        let currenciesOperationWrapper = currencyRepository.fetchAvailableCurrenciesWrapper()
        queue.addOperations(currenciesOperationWrapper.allOperations, waitUntilFinished: true)

        let currencies = try currenciesOperationWrapper.targetOperation.extractNoCancellableResultData()
        let selectedCurrencyId = settingsManager.selectedCurrencyId
        let currency = currencies.first(where: { $0.id == selectedCurrencyId }) ?? currencies.min { $0.id < $1.id }
        guard let currency = currency else {
            throw CurrencyManagerError.currencyListIsEmpty
        }

        availableCurrencies = currencies
        super.init(state: currency)
        sideEffectOnChangeState = { [weak self] in
            self?.saveCurrencyInSettings()
        }
    }

    init(
        settingsManager: SettingsManagerProtocol,
        availableCurrencies: [Currency],
        selectedCurrency: Currency
    ) {
        self.availableCurrencies = availableCurrencies
        self.settingsManager = settingsManager
        super.init(state: selectedCurrency)
        sideEffectOnChangeState = saveCurrencyInSettings
    }

    private func saveCurrencyInSettings() {
        settingsManager.selectedCurrencyId = selectedCurrency.id
    }
}

// MARK: - Error

enum CurrencyManagerError: Error {
    case currencyListIsEmpty
}
