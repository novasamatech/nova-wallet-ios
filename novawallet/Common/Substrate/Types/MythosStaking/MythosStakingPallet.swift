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
        @StringCodable var session: SessionIndex
        @StringCodable var stake: Balance
    }

    struct ReleaseRequest: Decodable, Equatable {
        @StringCodable var block: BlockNumber
        @StringCodable var amount: Balance

        func isRedeemable(at currentBlock: BlockNumber) -> Bool {
            block <= currentBlock
        }
    }

    typealias ReleaseQueue = [ReleaseRequest]

    struct CandidateStakeKey: JSONListConvertible {
        let candidate: AccountId
        let staker: AccountId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            candidate = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
            staker = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
