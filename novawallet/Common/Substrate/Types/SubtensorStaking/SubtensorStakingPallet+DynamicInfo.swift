import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct DynamicInfo: Decodable, Equatable {
        @StringCodable var netuid: UInt16
        @BytesCodable var ownerHotkey: AccountId
        @BytesCodable var ownerColdkey: AccountId
        @BytesCodable var subnetName: Data
        @BytesCodable var tokenSymbol: Data
        @StringCodable var tempo: UInt16
        @StringCodable var emission: Balance
        @StringCodable var alphaIn: Balance
        @StringCodable var taoIn: Balance
        @StringCodable var taoInEmission: Balance
        @StringCodable var networkRegisteredAt: UInt64
    }
}
