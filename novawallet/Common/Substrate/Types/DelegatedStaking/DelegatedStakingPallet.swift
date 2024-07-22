import Foundation
import SubstrateSdk
import BigInt

enum DelegatedStakingPallet {
    static let name = "DelegatedStaking"

    struct Delegation: Decodable, Equatable {
        @BytesCodable var agent: AccountId
        @StringCodable var amount: BigUInt
    }
}
