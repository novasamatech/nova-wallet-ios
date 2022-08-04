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

final class CurrencyRepository: JsonFileRepository<[Currency]> {}

extension CurrencyRepository: CurrencyRepositoryProtocol {
    func fetchAvailableCurrenciesWrapper() -> CompoundOperationWrapper<[Currency]> {
        fetch(by: R.file.currenciesJson(), defaultValue: [])
    }
}
