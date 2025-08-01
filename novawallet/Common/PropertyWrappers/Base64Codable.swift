import Foundation

@propertyWrapper
struct Base64Codable: Codable {
    let wrappedValue: Data

    init(wrappedValue: Data) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let base64String = try container.decode(String.self)

        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid base64 string"
                )
            )
        }

        wrappedValue = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(wrappedValue.base64EncodedString())
    }
}
