import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct DelegateInfo: Decodable, Equatable {
        @BytesCodable var delegateSs58: AccountId
        @StringCodable var take: UInt16
        let validatorPermits: [StringScaleMapper<UInt16>]
    }
}
