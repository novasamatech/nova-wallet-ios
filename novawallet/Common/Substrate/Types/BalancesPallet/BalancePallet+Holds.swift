import Foundation
import SubstrateSdk
import BigInt

extension BalancesPallet {
    struct HoldId: Decodable {
        let module: String
        let reason: String

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            module = try unkeyedContainer.decode(String.self)

            var reasonContainer = try unkeyedContainer.nestedUnkeyedContainer()

            reason = try reasonContainer.decode(String.self)
        }
    }

    struct Hold: Decodable {
        enum CodingKeys: String, CodingKey {
            case holdId = "id"
            case amount
        }

        let holdId: HoldId
        @StringCodable var amount: BigUInt
    }
}
