import Foundation
import BigInt

protocol HexConvertable {
    init(hex: String) throws
    func toHexWithPrefix() -> String
}

extension Data: HexConvertable {
    func toHexWithPrefix() -> String {
        toHex(includePrefix: true)
    }
}

extension BigUInt: HexConvertable {
    func toHexWithPrefix() -> String {
        toHexString()
    }

    init(hex: String) throws {
        guard let value = BigUInt.fromHexString(hex) else {
            throw CommonError.dataCorruption
        }

        self = value
    }
}

extension Bool: HexConvertable {
    func toHexWithPrefix() -> String {
        BigUInt(self ? 1 : 0).toHexString()
    }

    init(hex: String) throws {
        guard let value = BigUInt.fromHexString(hex) else {
            throw CommonError.dataCorruption
        }

        self = value == 1
    }
}

@propertyWrapper
struct HexCodable<T: HexConvertable>: Codable {
    let wrappedValue: T

    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let hexString = try container.decode(String.self)

        wrappedValue = try T(hex: hexString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(wrappedValue.toHexWithPrefix())
    }
}

@propertyWrapper
struct OptionHexCodable<T: HexConvertable>: Codable {
    let wrappedValue: T?

    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        wrappedValue = try HexCodable(from: decoder).wrappedValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let wrappedValue = wrappedValue {
            try container.encode(wrappedValue.toHexWithPrefix())
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedDecodingContainer {
    func decode<T: HexConvertable>(_ type: OptionHexCodable<T>.Type, forKey key: K) throws -> OptionHexCodable<T> {
        if let value = try decodeIfPresent(type, forKey: key) {
            return value
        }

        return OptionHexCodable(wrappedValue: nil)
    }
}
