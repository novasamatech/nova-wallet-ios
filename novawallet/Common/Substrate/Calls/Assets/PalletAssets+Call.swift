import Foundation
import SubstrateSdk
import BigInt

extension PalletAssets {
    struct TransferCall: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case target
            case amount
        }

        let assetId: JSON
        let target: MultiAddress
        @StringCodable var amount: BigUInt
    }

    struct MintCall<A: Codable>: Codable {
        enum CodingKeys: String, CodingKey {
            case assetId = "id"
            case beneficiary
            case amount
        }

        let assetId: A
        let beneficiary: MultiAddress
        @StringCodable var amount: Balance

        func runtimeCall(for palletName: String) -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: palletName,
                callName: "mint",
                args: self
            )
        }
    }
}
