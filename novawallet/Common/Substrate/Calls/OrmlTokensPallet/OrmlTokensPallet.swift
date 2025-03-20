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
        let who: MultiAddress
        let currencyId: C
        let newFree: Balance
        let newReserve: Balance

        func runtimeCall(for palletName: String) -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: palletName,
                callName: "set_balance",
                args: self
            )
        }
    }
}
