import RobinHood
import SoraKeystore

protocol UserCurrencyRepositoryProtocol {
    func selectedCurrency() -> CompoundOperationWrapper<Currency?>
    func setSelectedCurrency(_ currency: Currency)
}

final class UserCurrencyRepository: UserCurrencyRepositoryProtocol {
    private let currencyRepository: CurrencyRepositoryProtocol
    private let settingManager: SettingsManagerProtocol

    init(
        currencyRepository: CurrencyRepositoryProtocol,
        settingManager: SettingsManagerProtocol
    ) {
        self.currencyRepository = currencyRepository
        self.settingManager = settingManager
    }

    func selectedCurrency() -> CompoundOperationWrapper<Currency?> {
        let currenciesOperationWrapper = currencyRepository.fetchAvailableCurrenciesWrapper()

        let mappingOperation = ClosureOperation<Currency?> { [weak self] in
            guard let self = self else {
                return nil
            }
            let selectedCurrencyId = self.settingManager.selectedCurrencyId
            let currencies = try currenciesOperationWrapper.targetOperation.extractNoCancellableResultData()
            return currencies.first(where: { $0.id == selectedCurrencyId }) ?? currencies.min { $0.id < $1.id }
        }

        currenciesOperationWrapper.allOperations.forEach {
            mappingOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: currenciesOperationWrapper.allOperations
        )
    }

    func setSelectedCurrency(_ currency: Currency) {
        settingManager.selectedCurrencyId = currency.id
    }
}
