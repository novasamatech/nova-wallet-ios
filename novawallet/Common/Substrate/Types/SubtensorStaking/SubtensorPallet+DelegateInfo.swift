import Foundation
import BigInt
import SubstrateSdk

extension SubtensorPallet {
    struct DelegateInfo: Decodable, Equatable {
        @BytesCodable var delegateSs58: AccountId
        let validatorPermits: [StringScaleMapper<UInt16>]
    }
}
