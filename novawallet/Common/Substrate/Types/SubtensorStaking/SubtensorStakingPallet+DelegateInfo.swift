import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    struct DelegateSubnetStake: Decodable, Equatable {
        let netuid: UInt16
        let stake: Balance

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            netuid = try container.decode(StringScaleMapper<UInt16>.self).value
            stake = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }

    struct DelegateNomination: Decodable, Equatable {
        let nominator: AccountId
        let stakes: [DelegateSubnetStake]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            nominator = try container.decode(BytesCodable.self).wrappedValue
            stakes = try container.decode([DelegateSubnetStake].self)
        }
    }

    struct DelegateInfo: Decodable, Equatable {
        @BytesCodable var delegateSs58: AccountId
        @StringCodable var take: UInt16
        let nominators: [DelegateNomination]
        @BytesCodable var ownerSs58: AccountId
        let registrations: [StringScaleMapper<UInt16>]
        let validatorPermits: [StringScaleMapper<UInt16>]
        @StringCodable var returnPer1000: Balance
        @StringCodable var totalDailyReturn: Balance

        var registeredNetuids: [UInt16] {
            registrations.map(\.value)
        }

        var isRegisteredOnRoot: Bool {
            registeredNetuids.contains(SubtensorStakingPallet.rootNetuid)
        }

        var validatorPermitNetuids: [UInt16] {
            validatorPermits.map(\.value)
        }
    }
}
