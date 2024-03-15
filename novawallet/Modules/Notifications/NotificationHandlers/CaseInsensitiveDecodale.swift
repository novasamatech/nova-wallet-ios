protocol CaseInsensitiveDecodale: Decodable {}

extension RawRepresentable where Self.RawValue == String, Self: CaseInsensitiveDecodale {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)

        if let value = Self(rawValue: rawString.lowercased()) {
            self = value
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot initialize RawRepresentable from invalid String value \(rawString)"
            )
        }
    }
}
