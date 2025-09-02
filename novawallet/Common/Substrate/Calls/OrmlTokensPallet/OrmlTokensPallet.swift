import Foundation
import SubstrateSdk
import BigInt

enum OrmlTokensPallet {
    struct TransferCall: Codable {
        enum CodingKeys: String, CodingKey {
            case dest
            case currencyId = "currency_id"
            case amount
        }

        let dest: MultiAddress
        let currencyId: JSON
        @StringCodable var amount: BigUInt
    }

    struct TransferAllCall: Codable {
        enum CodingKeys: String, CodingKey {
            case dest
            case currencyId = "currency_id"
            case keepAlive = "keep_alive"
        }

        let dest: MultiAddress
        let currencyId: JSON
        let keepAlive: Bool
    }

    struct SetBalanceCall<C: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case who
            case currencyId = "currency_id"
            case newFree = "new_free"
            case newReserve = "new_reserved"
        }

        let who: MultiAddress
        let currencyId: C
        @StringCodable var newFree: Balance
        @StringCodable var newReserve: Balance

        func runtimeCall(for palletName: String) -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: palletName,
                callName: "set_balance",
                args: self
            )
        }
    }
}
