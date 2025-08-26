import Foundation
import SubstrateSdk

extension HydrationApi {
    static var currenciesAccountPath: StateCallPath {
        StateCallPath(module: "CurrenciesApi", method: "account")
    }

    struct CurrencyData: Decodable {
        @StringCodable var free: Balance
        @StringCodable var reserved: Balance
        @StringCodable var frozen: Balance
    }
}
