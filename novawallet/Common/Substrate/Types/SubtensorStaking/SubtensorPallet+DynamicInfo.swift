import Foundation
import BigInt
import SubstrateSdk

extension SubtensorPallet {
    struct DynamicInfo: Decodable, Equatable {
        @StringCodable var netuid: UInt16
        @StringCodable var taoInEmission: Balance
        @StringCodable var networkRegisteredAt: UInt64
    }
}
