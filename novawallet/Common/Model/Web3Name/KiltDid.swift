import SubstrateSdk
import BigInt

enum KiltDid {
    struct Key: JSONListConvertible, Hashable {
        let didIdentifier: AccountId
        let serviceId: String

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            didIdentifier = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
            serviceId = try jsonList[1].map(to: AsciiDataString.self, with: context).wrappedValue
        }
    }

    struct Endpoint: Decodable {
        @AsciiDataString var serviceId: String
        var serviceTypes: [AsciiDataString]
        var urls: [AsciiDataString]

        enum CodingKeys: String, CodingKey {
            case serviceId = "id"
            case serviceTypes
            case urls
        }
    }
}
