import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct RoundInfo: Codable, Equatable {
        @StringCodable var current: RoundIndex
        @StringCodable var first: BlockNumber
        @StringCodable var length: UInt32
    }

    struct Range<T: Codable & Equatable>: Codable, Equatable {
        let min: T
        let ideal: T
        let max: T
    }

    struct InflationConfig: Codable, Equatable {
        let expect: Range<StringScaleMapper<BigUInt>>
        let annual: Range<StringScaleMapper<BigUInt>>
    }

    typealias InflationDistributionPercent = UInt8

    struct ParachainBondConfig: Codable, Equatable {
        @StringCodable var percent: InflationDistributionPercent
    }

    struct InflationDistributionAccount: Codable, Equatable {
        @StringCodable var percent: InflationDistributionPercent
    }

    typealias InflationDistributionInfo = [InflationDistributionAccount]
}
