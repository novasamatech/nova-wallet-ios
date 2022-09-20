import Foundation
import SubstrateSdk
import BigInt

extension Referenda {
    struct Deposit: Decodable {
        let who: AccountId
        @StringCodable var amount: BigUInt
    }
}
