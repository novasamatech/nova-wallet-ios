import Foundation
import BigInt
import SubstrateSdk

extension SubtensorPallet {
    struct StakeInfo: Decodable, Equatable {
        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var stake: Balance
        let isRegistered: Bool
    }

    struct StakeAvailability: Decodable, Equatable {
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

extension SubtensorPallet {
    struct MinerCollateralState: Decodable, Equatable {
        @StringCodable var locked: Balance
    }
}
