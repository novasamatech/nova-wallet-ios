import Foundation
import SubstrateSdk
import BigInt

extension HydraDx {
    struct SetCurrencyCall: Codable {
        @StringCodable var currency: HydraDx.AssetId

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: HydraDx.multiTxPaymentModule, callName: "set_currency", args: self)
        }
    }

    struct LinkReferralCodeCall: Codable {
        @BytesCodable var code: Data

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: HydraDx.referralsModule, callName: "link_code", args: self)
        }
    }
}
