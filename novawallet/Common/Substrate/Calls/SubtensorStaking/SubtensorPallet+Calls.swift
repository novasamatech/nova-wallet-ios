import Foundation
import BigInt
import SubstrateSdk

enum SubtensorCallError: Error {
    case amountExceedsMaxU64(BigUInt)
}

extension SubtensorPallet {
    static func ensureU64Amount(_ amount: BigUInt) throws {
        guard amount <= BigUInt(UInt64.max) else {
            throw SubtensorCallError.amountExceedsMaxU64(amount)
        }
    }

    struct AddStakeCall: Codable {
        enum CodingKeys: String, CodingKey {
            case hotkey
            case netuid
            case amountStaked = "amount_staked"
        }

        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var amountStaked: Balance

        func runtimeCall() throws -> RuntimeCall<Self> {
            try SubtensorPallet.ensureU64Amount(amountStaked)

            return .init(
                moduleName: SubtensorPallet.name,
                callName: "add_stake",
                args: self
            )
        }
    }

    struct RemoveStakeCall: Codable {
        enum CodingKeys: String, CodingKey {
            case hotkey
            case netuid
            case amountUnstaked = "amount_unstaked"
        }

        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @StringCodable var amountUnstaked: Balance

        func runtimeCall() throws -> RuntimeCall<Self> {
            try SubtensorPallet.ensureU64Amount(amountUnstaked)

            return .init(
                moduleName: SubtensorPallet.name,
                callName: "remove_stake",
                args: self
            )
        }
    }

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
        @StringCodable var amountStaked: Balance
        @StringCodable var limitPrice: Balance
        let allowPartial: Bool

        func runtimeCall() throws -> RuntimeCall<Self> {
            try SubtensorPallet.ensureU64Amount(amountStaked)
            try SubtensorPallet.ensureU64Amount(limitPrice)

            return .init(
                moduleName: SubtensorPallet.name,
                callName: "add_stake_limit",
                args: self
            )
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
        @StringCodable var amountUnstaked: Balance
        @StringCodable var limitPrice: Balance
        let allowPartial: Bool

        func runtimeCall() throws -> RuntimeCall<Self> {
            try SubtensorPallet.ensureU64Amount(amountUnstaked)
            try SubtensorPallet.ensureU64Amount(limitPrice)

            return .init(
                moduleName: SubtensorPallet.name,
                callName: "remove_stake_limit",
                args: self
            )
        }
    }

    struct RemoveStakeFullLimitCall: Codable {
        enum CodingKeys: String, CodingKey {
            case hotkey
            case netuid
            case limitPrice = "limit_price"
        }

        @BytesCodable var hotkey: AccountId
        @StringCodable var netuid: UInt16
        @OptionStringCodable var limitPrice: Balance?

        func runtimeCall() throws -> RuntimeCall<Self> {
            if let limitPrice {
                try SubtensorPallet.ensureU64Amount(limitPrice)
            }

            return .init(
                moduleName: SubtensorPallet.name,
                callName: "remove_stake_full_limit",
                args: self
            )
        }
    }

    struct ClaimRootWithHotkeyCall: Codable {
        @BytesCodable var hotkey: AccountId

        func runtimeCall() -> RuntimeCall<Self> {
            .init(
                moduleName: SubtensorPallet.name,
                callName: "claim_root_with_hotkey",
                args: self
            )
        }
    }
}
