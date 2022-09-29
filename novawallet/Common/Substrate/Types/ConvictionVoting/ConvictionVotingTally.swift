import Foundation
import SubstrateSdk
import BigInt

extension ConvictionVoting {
    struct Tally: Decodable {
        @StringCodable var ayes: BigUInt
        @StringCodable var nays: BigUInt
        @StringCodable var support: BigUInt
    }
}
