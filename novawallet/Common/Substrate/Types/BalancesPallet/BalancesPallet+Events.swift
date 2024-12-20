import Foundation
import SubstrateSdk
import BigInt

extension BalancesPallet {
    struct DepositEvent: Decodable {
        let accountId: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }

    struct WithdrawEvent: Decodable {
        let accountId: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }

    struct MintedEvent: Decodable {
        let accountId: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            accountId = try unkeyedContainer.decode(BytesCodable.self).wrappedValue
            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }

    struct TransferEvent: Decodable {
        let sender: AccountId
        let receiver: AccountId
        let amount: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            sender = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

            receiver = try unkeyedContainer.decode(AccountIdCodingWrapper.self).wrappedValue

            amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
