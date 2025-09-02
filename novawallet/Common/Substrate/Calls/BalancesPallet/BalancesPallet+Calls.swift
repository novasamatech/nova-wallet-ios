import Foundation
import SubstrateSdk

extension BalancesPallet {
    struct ForceSetBalance: Codable {
        enum CodingKeys: String, CodingKey {
            case who
            case newFree = "new_free"
        }

        let who: MultiAddress
        @StringCodable var newFree: Balance

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: BalancesPallet.name,
                callName: "force_set_balance",
                args: self
            )
        }
    }
}
