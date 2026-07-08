import Foundation
import BigInt
import SubstrateSdk

extension SubtensorPallet {
    struct AddStakeLimitCall: Codable {
        enum CodingKeys: String, CodingKey {
            case hotkey
            case netuid
            case amountStaked = "amount_staked"
            case limitPrice = "limit_price"
            case allowPartial = "allow_partial"
        }

        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var amountStaked: BigUInt
        @StringCodable var limitPrice: BigUInt
        var allowPartial: Bool

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: SubtensorPallet.name, callName: "add_stake_limit", args: self)
        }
    }

    struct RemoveStakeLimitCall: Codable {
        enum CodingKeys: String, CodingKey {
            case hotkey
            case netuid
            case amountUnstaked = "amount_unstaked"
            case limitPrice = "limit_price"
            case allowPartial = "allow_partial"
        }

        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var amountUnstaked: BigUInt
        @StringCodable var limitPrice: BigUInt
        var allowPartial: Bool

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: SubtensorPallet.name, callName: "remove_stake_limit", args: self)
        }
    }

    struct MoveStakeCall: Codable {
        enum CodingKeys: String, CodingKey {
            case originHotkey = "origin_hotkey"
            case destinationHotkey = "destination_hotkey"
            case originNetuid = "origin_netuid"
            case destinationNetuid = "destination_netuid"
            case alphaAmount = "alpha_amount"
        }

        @BytesCodable var originHotkey: AccountId
        @BytesCodable var destinationHotkey: AccountId
        @StringCodable var originNetuid: UInt16
        @StringCodable var destinationNetuid: UInt16
        @StringCodable var alphaAmount: BigUInt

        func runtimeCall() -> RuntimeCall<Self> {
            .init(moduleName: SubtensorPallet.name, callName: "move_stake", args: self)
        }
    }
}
