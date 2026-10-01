import Foundation
import BigInt
import SubstrateSdk

extension SubtensorStakingPallet {
    static var stakeAddedEventPath: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "StakeAdded")
    }

    static var stakeRemovedEventPath: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "StakeRemoved")
    }

    struct StakeAddedEvent: Decodable {
        let coldkey: AccountId
        let hotkey: AccountId
        let tao: Balance
        let alpha: Balance
        let netuid: UInt16
        let fee: Balance

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            coldkey = try container.decode(BytesCodable.self).wrappedValue
            hotkey = try container.decode(BytesCodable.self).wrappedValue
            tao = try container.decode(StringScaleMapper<Balance>.self).value
            alpha = try container.decode(StringScaleMapper<Balance>.self).value
            netuid = try container.decode(StringScaleMapper<UInt16>.self).value
            fee = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }

    struct StakeRemovedEvent: Decodable {
        let coldkey: AccountId
        let hotkey: AccountId
        let tao: Balance
        let alpha: Balance
        let netuid: UInt16
        let fee: Balance

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            coldkey = try container.decode(BytesCodable.self).wrappedValue
            hotkey = try container.decode(BytesCodable.self).wrappedValue
            tao = try container.decode(StringScaleMapper<Balance>.self).value
            alpha = try container.decode(StringScaleMapper<Balance>.self).value
            netuid = try container.decode(StringScaleMapper<UInt16>.self).value
            fee = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }
}
