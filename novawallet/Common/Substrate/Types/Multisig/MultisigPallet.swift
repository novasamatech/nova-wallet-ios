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
        enum CodingKeys: String, CodingKey {
            case height
            case index
        }

        var height: BlockNumber
        var index: UInt32

        init(from decoder: Decoder) throws {
            if let keyedContainer = try? decoder.container(keyedBy: CodingKeys.self) {
                let height = try keyedContainer.decode(StringCodable<BlockNumber>.self, forKey: .height)
                let index = try keyedContainer.decode(StringCodable<UInt32>.self, forKey: .index)

                self.height = height.wrappedValue
                self.index = index.wrappedValue
            } else {
                var unkeyedContainer = try decoder.unkeyedContainer()

                let height = try unkeyedContainer.decode(StringCodable<BlockNumber>.self)
                let index = try unkeyedContainer.decode(StringCodable<UInt32>.self)

                self.height = height.wrappedValue
                self.index = index.wrappedValue
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(height.description, forKey: .height)
            try container.encode(index.description, forKey: .index)
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

            accountId = try jsonList[0].map(to: AccountId.self, with: context)
            callHash = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }
}
