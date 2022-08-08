//
//  CurrencyRepositoryProtocol.swift
//  novawallet
//
//  Created by Holyberry on 04.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation
import RobinHood

protocol CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]>
}

final class CurrencyRepository: JsonFileRepository<[Currency]> {
    static let shared = CurrencyRepository()

    @Atomic(defaultValue: [])
    private var currencies: [Currency]
}

extension CurrencyRepository: CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]> {
        guard currencies.isEmpty else {
            return CompoundOperationWrapper.createWithResult(currencies)
        }
        let fetchCurrenciesOperation = fetchOperation(
            by: R.file.currenciesJson(),
            defaultValue: []
        )
        let cacheOperation: BaseOperation<[Currency]> = ClosureOperation { [weak self] in
            guard let result = try?
                fetchCurrenciesOperation.extractNoCancellableResultData() else {
                return []
            }
            self?.currencies = result
            return result
        }
        cacheOperation.addDependency(fetchCurrenciesOperation)

        return CompoundOperationWrapper(
            targetOperation: cacheOperation,
            dependencies: [fetchCurrenciesOperation]
        )
    }
}
