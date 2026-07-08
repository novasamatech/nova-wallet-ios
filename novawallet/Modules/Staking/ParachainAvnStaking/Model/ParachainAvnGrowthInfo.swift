import Foundation
import SubstrateSdk
import BigInt

extension ParachainAvn {
    /// Pointer to the current `Growth` period on EWX.
    ///
    /// Storage shape: `{ startEraIndex: u32, index: u32 }` at
    /// `ParachainStaking.GrowthPeriod`. `index` is the current period
    /// number; the most recent completed period is `index - 1`.
    struct GrowthPeriod: Decodable, Equatable {
        let startEraIndex: UInt32
        let index: UInt32

        private enum CodingKeys: String, CodingKey {
            case startEraIndex
            case start // some chain versions encode it as `start`
            case index
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let mapper = try? container.decode(StringScaleMapper<UInt32>.self, forKey: .startEraIndex) {
                startEraIndex = mapper.value
            } else if let mapper = try? container.decode(StringScaleMapper<UInt32>.self, forKey: .start) {
                startEraIndex = mapper.value
            } else {
                startEraIndex = 0
            }

            index = try container.decode(StringScaleMapper<UInt32>.self, forKey: .index).value
        }

        init(startEraIndex: UInt32, index: UInt32) {
            self.startEraIndex = startEraIndex
            self.index = index
        }
    }

    /// Reward accumulation snapshot for a single growth period.
    ///
    /// Storage shape: `{ numberOfAccumulations, totalStakeAccumulated,
    ///   totalStakerReward, totalPoints, collatorScores, txId,
    ///   triggered }` at `ParachainStaking.Growth(period_index)`.
    /// Only the first three fields are needed for APR computation;
    /// the rest are decoded leniently and ignored.
    ///
    /// APR = (totalStakerReward / totalStakeAccumulated) *
    ///       (eras_per_year / numberOfAccumulations)
    /// On EWX `numberOfAccumulations` is typically 28 (a 28-era period)
    /// and `eras_per_year` is 365 (one era per day).
    struct GrowthInfo: Decodable, Equatable {
        let numberOfAccumulations: UInt32
        let totalStakeAccumulated: BigUInt
        let totalStakerReward: BigUInt

        private enum CodingKeys: String, CodingKey {
            case numberOfAccumulations
            case totalStakeAccumulated
            case totalStakerReward
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            numberOfAccumulations = try container
                .decode(StringScaleMapper<UInt32>.self, forKey: .numberOfAccumulations).value
            totalStakeAccumulated = try container
                .decode(StringScaleMapper<BigUInt>.self, forKey: .totalStakeAccumulated).value
            totalStakerReward = try container
                .decode(StringScaleMapper<BigUInt>.self, forKey: .totalStakerReward).value
        }

        init(numberOfAccumulations: UInt32, totalStakeAccumulated: BigUInt, totalStakerReward: BigUInt) {
            self.numberOfAccumulations = numberOfAccumulations
            self.totalStakeAccumulated = totalStakeAccumulated
            self.totalStakerReward = totalStakerReward
        }
    }
}
