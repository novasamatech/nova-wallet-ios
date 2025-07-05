import SubstrateSdk
import Operation_iOS
import BigInt

enum MultisigPallet {
    static var name: String { "Multisig" }

    struct MultisigDefinition: Codable {
        enum CodingKeys: String, CodingKey {
            case timepoint = "when"
            case deposit
            case depositor
            case approvals
        }

        let timepoint: MultisigTimepoint
        @StringCodable var deposit: BigUInt
        @BytesCodable var depositor: AccountId
        var approvals: [BytesCodable]
    }

    struct MultisigTimepoint: Codable {
        @StringCodable var height: BlockNumber
        @StringCodable var index: UInt32
    }

    struct EventTimePoint: Decodable, Hashable {
        let height: BlockNumber
        let index: UInt32

        init(
            height: BlockNumber,
            index: UInt32
        ) {
            self.height = height
            self.index = index
        }

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            let height = try unkeyedContainer.decode(StringCodable<BlockNumber>.self)
            let index = try unkeyedContainer.decode(StringCodable<UInt32>.self)

            self.height = height.wrappedValue
            self.index = index.wrappedValue
        }
    }

    struct CallHashKey: JSONListConvertible, Hashable {
        let accountId: AccountId
        let callHash: Substrate.CallHash

        init(
            accountId: AccountId,
            callHash: Substrate.CallHash
        ) {
            self.accountId = accountId
            self.callHash = callHash
        }

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            accountId = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
            callHash = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
