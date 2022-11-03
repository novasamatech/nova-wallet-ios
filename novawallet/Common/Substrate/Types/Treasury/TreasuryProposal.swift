import Foundation
import SubstrateSdk
import BigInt

extension Treasury {
    struct Proposal: Decodable {
        let proposer: AccountId
        @StringCodable var value: BigUInt
        @BytesCodable var beneficiary: AccountId
    }
}
