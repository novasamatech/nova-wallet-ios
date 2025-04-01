import Foundation
import SubstrateSdk
import BigInt

extension BalancesPallet {
    struct FreezeId: Decodable {
        let module: String
        let reason: String

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            module = try unkeyedContainer.decode(String.self)

            var reasonContainer = try unkeyedContainer.nestedUnkeyedContainer()

            reason = try reasonContainer.decode(String.self)
        }
    }

    struct Freeze: Decodable {
        enum CodingKeys: String, CodingKey {
            case freezeId = "id"
            case amount
        }

        let freezeId: FreezeId
        @StringCodable var amount: BigUInt
    }

    typealias Freezes = [Freeze]
}
