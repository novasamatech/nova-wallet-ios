import Foundation
import SubstrateSdk

extension ParachainStaking {
    struct RoundInfo: Codable, Equatable {
        @StringCodable var current: RoundIndex
        @StringCodable var first: BlockNumber
        @StringCodable var length: UInt32
    }
}
