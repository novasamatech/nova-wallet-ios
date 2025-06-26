import SubstrateSdk
import Operation_iOS

enum MultisigPallet {
    static var name: String { "Multisig" }

    struct MultisigDefinition: Codable {
        enum CodingKeys: String, CodingKey {
            case timepoint = "when"
            case depositor
            case approvals
        }

        let timepoint: MultisigTimepoint
        @BytesCodable var depositor: AccountId
        var approvals: [BytesCodable]
    }

    struct MultisigTimepoint: Codable {
        @StringCodable var height: BlockNumber
        @StringCodable var index: UInt32

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            height = try unkeyedContainer.decode(UInt32.self)
            index = try unkeyedContainer.decode(UInt32.self)
        }
    }

    struct CallHashKey: JSONListConvertible, Hashable {
        let accountId: AccountId
        let callHash: CallHash

        init(
            accountId: AccountId,
            callHash: CallHash
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

            accountId = try jsonList[0].map(to: AccountId.self, with: context)
            callHash = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
