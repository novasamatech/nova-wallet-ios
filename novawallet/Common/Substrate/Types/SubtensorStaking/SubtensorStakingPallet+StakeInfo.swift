import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct StakeInfo: Decodable, Equatable {
        @BytesCodable var hotkey: AccountId
        @BytesCodable var coldkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var stake: Balance
        // locked/taoEmission/drain are literal zeros at spec 448 (stake_info.rs:79-82);
        // real lock data comes only from StakeAvailability
        @StringCodable var locked: Balance
        @StringCodable var emission: Balance
        @StringCodable var taoEmission: Balance
        @StringCodable var drain: Balance
        let isRegistered: Bool
    }

    struct StakeAvailability: Decodable, Equatable {
        @StringCodable var total: Balance
        @StringCodable var locked: Balance
        @StringCodable var available: Balance
    }

    struct SubnetStakeAvailability: Decodable, Equatable {
        let netuid: UInt16
        let availability: StakeAvailability

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            netuid = try container.decode(StringScaleMapper<UInt16>.self).value
            availability = try container.decode(StakeAvailability.self)
        }
    }

    struct ColdkeyStakeAvailability: Decodable, Equatable {
        let coldkey: AccountId
        let subnets: [SubnetStakeAvailability]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            coldkey = try container.decode(BytesCodable.self).wrappedValue
            subnets = try container.decode([SubnetStakeAvailability].self)
        }
    }
}
