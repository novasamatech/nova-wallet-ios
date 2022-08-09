import Foundation
import SoraKeystore

enum CurrencyManagerError: Error {
    case notFoundCurrencies
}

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

final class CurrencyManager: StateObservableManager<Currency>, CurrencyManagerProtocol {
    let availableCurrencies: [Currency]
    var selectedCurrency: Currency {
        get {
            return state
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
            throw CurrencyManagerError.notFoundCurrencies
        }

        availableCurrencies = currencies
        super.init(state: currency)
        sideEffectOnChangeState = saveCurrencyInSettings
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
        settingsManager.selectedCurrencyId = state.id
    }
}

extension CurrencyManager {
    static let shared = CurrencyManager()

    private convenience init?() {
        try? self.init(
            currencyRepository: CurrencyRepository.shared,
            settingsManager: SettingsManager.shared,
            queue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
