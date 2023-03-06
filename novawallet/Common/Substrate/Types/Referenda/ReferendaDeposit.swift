import Foundation
import SubstrateSdk
import BigInt

extension Referenda {
    struct Deposit: Decodable {
        @BytesCodable var who: AccountId
        @StringCodable var amount: BigUInt
    }
}
