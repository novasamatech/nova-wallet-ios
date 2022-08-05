//
//  UserCurrencyRepository.swift
//  novawallet
//
//  Created by Holyberry on 05.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import RobinHood
import SoraKeystore

protocol UserCurrencyRepositoryProtocol {
    func selectedCurrency() -> CompoundOperationWrapper<Currency?>
    func setSelectedCurrency(_ currency: Currency) -> BaseOperation<Void>
}

final class UserCurrencyRepository: UserCurrencyRepositoryProtocol {
    private let currencyRepository: CurrencyRepositoryProtocol
    private let settingManager: SettingsManagerProtocol
    
    @Atomic(defaultValue: [])
    private(set) var currencies: [Currency]

    init(
        currencyRepository: CurrencyRepositoryProtocol,
        settingManager: SettingsManagerProtocol
    ) {
        self.currencyRepository = currencyRepository
        self.settingManager = settingManager
    }

    func selectedCurrency() -> CompoundOperationWrapper<Currency?> {
        let currentCurrencyOperation: BaseOperation<Currency?> = ClosureOperation { [weak self] in
            guard let self = self else {
                return nil
            }
            let selectedCurrencyId = self.settingManager.selectedCurrencyId
            return self.currencies.first(where: { $0.id == selectedCurrencyId })
        }

        let allCurrenciesOperationWrapper = currencyRepository.fetchAvailableCurrenciesWrapper()
        allCurrenciesOperationWrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            guard let currencies = try?
                allCurrenciesOperationWrapper.targetOperation.extractNoCancellableResultData() else {
                return
            }
            self.currencies = currencies
        }
        allCurrenciesOperationWrapper.allOperations.forEach {
            currentCurrencyOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: currentCurrencyOperation,
            dependencies: allCurrenciesOperationWrapper.allOperations
        )
    }

    func setSelectedCurrency(_ currency: Currency) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            self?.settingManager.selectedCurrencyId = currency.id
        }
    }
}
