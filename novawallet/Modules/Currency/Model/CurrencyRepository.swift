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

    private var currencies: [Currency] = []
}

extension CurrencyRepository: CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]> {
        guard currencies.isEmpty else {
            return CompoundOperationWrapper.createWithResult(currencies)
        }
        let fetchOperation = fetchOperation(by: R.file.currenciesJson(), defaultValue: [])
        let cacheOperation: BaseOperation<[Currency]> = ClosureOperation {
            guard let result = try?
                fetchOperation.extractNoCancellableResultData() else {
                return []
            }
            self.currencies = result
            return result
        }
        cacheOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: cacheOperation,
            dependencies: [fetchOperation]
        )
    }
}
