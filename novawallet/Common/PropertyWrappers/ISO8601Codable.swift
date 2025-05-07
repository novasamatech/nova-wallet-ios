import Foundation

@propertyWrapper
struct ISO8601Codable: Codable {
    let wrappedValue: Date?

    init(wrappedValue: Date?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else {
            wrappedValue = nil
            return
        }

        let string = try container.decode(String.self)
        guard !string.isEmpty else {
            wrappedValue = nil
            return
        }

        wrappedValue = try Date(
            string,
            strategy: Date.ISO8601FormatStyle()
                .year().month().day()
                .parseStrategy
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let wrappedValue else {
            try container.encodeNil()
            return
        }

        let value = wrappedValue.formatted(
            Date.ISO8601FormatStyle()
                .year().month().day()
        )

        try container.encode(value)
    }
}
