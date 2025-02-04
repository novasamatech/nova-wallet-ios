import Foundation
import SubstrateSdk

enum MythosStakingPallet {
    static let name = "CollatorStaking"

    struct UserStakeUnavailable: Decodable, Equatable {
        let amount: Balance
        let blockNumber: BlockNumber

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            amount = try container.decode(StringScaleMapper<Balance>.self).value
            blockNumber = try container.decode(StringScaleMapper<BlockNumber>.self).value
        }
    }

    struct UserStake: Decodable, Equatable {
        @StringCodable var stake: Balance
        let candidates: [BytesCodable]
        let maybeLastUnstake: UserStakeUnavailable?
        @OptionStringCodable var maybeLastRewardSession: SessionIndex?
    }

    struct CandidateStakeInfo: Codable, Equatable {
        @StringCodable var stake: Balance
    }

    struct ReleaseRequest: Decodable, Equatable {
        @StringCodable var block: BlockNumber
        @StringCodable var amount: Balance
    }

    typealias ReleaseQueue = [ReleaseRequest]
}
