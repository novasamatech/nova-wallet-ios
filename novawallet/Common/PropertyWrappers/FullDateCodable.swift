import Foundation

/// Decodes a calendar day sent as `yyyy-MM-dd`. `withFullDate` rejects a trailing time component,
/// unpadded components and any separator other than a dash, so a malformed value fails the whole
/// payload rather than being silently coerced.
@propertyWrapper
struct FullDateCodable: Codable, Equatable {
    let wrappedValue: Date

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        return formatter
    }()

    init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let rawValue = try container.decode(String.self)

        // `withFullDate` alone still accepts unpadded components, slash separators and a trailing
        // time, so the parsed date is required to round trip back to the exact input.
        guard
            let date = Self.formatter.date(from: rawValue),
            Self.formatter.string(from: date) == rawValue else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid full date: \(rawValue)"
                )
            )
        }

        wrappedValue = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(Self.formatter.string(from: wrappedValue))
    }
}
