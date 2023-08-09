import Foundation
import SubstrateSdk
import BigInt

enum NominationPools {
    typealias PoolId = UInt32

    struct PoolMember: Decodable, Equatable {
        @StringCodable var poolId: PoolId
        @StringCodable var points: BigUInt
        @StringCodable var lastRecordedRewardCounter: BigUInt
        let unbondingEras: [SupportPallet.KeyValue<StringScaleMapper<EraIndex>, StringScaleMapper<BigUInt>>]
    }

    enum PoolState: Decodable, Equatable {
        case open
        case blocked
        case destroying
        case unsuppored

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let rawValue = try container.decode(String.self)

            switch rawValue {
            case "Open":
                self = .open
            case "Blocked":
                self = .blocked
            case "Destroying":
                self = .destroying
            default:
                self = .unsuppored
            }
        }
    }

    struct AccountCommission: Decodable, Equatable {
        let percent: BigUInt
        let accountId: AccountId

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            percent = try container.decode(StringScaleMapper<BigUInt>.self).value
            accountId = try container.decode(BytesCodable.self).wrappedValue
        }
    }

    struct Commission: Decodable, Equatable {
        let current: AccountCommission?
    }

    struct BondedPool: Decodable, Equatable {
        @StringCodable var points: BigUInt
        @StringCodable var memberCounter: UInt32
        let commission: Commission?
        let state: PoolState

        func checkPoolSpare(for maxMembersPerPool: UInt32?) -> Bool {
            guard state == .open else {
                return false
            }

            if let maxMembersPerPool = maxMembersPerPool {
                return memberCounter < maxMembersPerPool
            } else {
                return true
            }
        }
    }

    struct RewardPool: Decodable, Equatable {
        @StringCodable var lastRecordedRewardCounter: BigUInt
    }

    struct UnbondPool: Decodable, Equatable {
        @StringCodable var points: BigUInt
        @StringCodable var balance: BigUInt
    }

    struct SubPools: Decodable, Equatable {
        let noEra: UnbondPool
        let withEra: [SupportPallet.KeyValue<StringScaleMapper<EraIndex>, UnbondPool>]
    }

    enum AccountType: UInt8 {
        case bonded
        case reward
    }
}
