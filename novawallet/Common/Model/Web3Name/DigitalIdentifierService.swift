import SubstrateSdk
import BigInt

enum DigitalIdentifierService {
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
            let data = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
            serviceId = String(data: data, encoding: .utf8) ?? ""
        }
    }

    struct Endpoint: Decodable {
        var id: String
        var serviceTypes: [String]
        var urls: [String]

        enum CodingKeys: String, CodingKey {
            case id
            case serviceTypes
            case urls
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decode(BytesCodable.self, forKey: .id).wrappedValue
            self.id = String(data: id, encoding: .utf8) ?? ""
            serviceTypes = try container.decode([StringContainer].self, forKey: .serviceTypes).map(\.value)
            urls = try container.decode([StringContainer].self, forKey: .urls).map(\.value)
        }
    }
}
