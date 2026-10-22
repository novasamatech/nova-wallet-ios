import Foundation

indirect enum NovaAuthJSON {
    case object([String: NovaAuthJSON])
    case array([NovaAuthJSON])
    case string(String)
    case number(String)
    case boolean(Bool)
    case null

    static func parse(_ data: Data, limit: Int) throws -> NovaAuthJSON {
        guard !data.isEmpty, data.count <= limit, String(data: data, encoding: .utf8) != nil else {
            throw NovaAuthError.invalidResponse
        }
        var parser = NovaAuthJSONParser(bytes: Array(data))
        let result = try parser.value(depth: 0)
        parser.skipWhitespace()
        guard parser.index == data.count else { throw NovaAuthError.invalidResponse }
        return result
    }

    func object(keys: Set<String>? = nil) throws -> [String: NovaAuthJSON] {
        guard case let .object(value) = self, keys == nil || Set(value.keys) == keys else {
            throw NovaAuthError.invalidResponse
        }
        return value
    }

    func string() throws -> String {
        guard case let .string(value) = self else { throw NovaAuthError.invalidResponse }
        return value
    }

    func unixSeconds() throws -> Int64 {
        guard case let .number(value) = self,
              value.utf8.allSatisfy({ (48 ... 57).contains($0) }), let integer = Int64(value) else {
            throw NovaAuthError.invalidResponse
        }
        return integer
    }
}

private struct NovaAuthJSONParser {
    let bytes: [UInt8]
    var index = 0

    mutating func value(depth: Int) throws -> NovaAuthJSON {
        skipWhitespace()
        guard index < bytes.count else { throw NovaAuthError.invalidResponse }
        switch bytes[index] {
        case 123: return try object(depth: depth + 1)
        case 91: return try array(depth: depth + 1)
        case 34: return .string(try string())
        case 116: try literal("true"); return .boolean(true)
        case 102: try literal("false"); return .boolean(false)
        case 110: try literal("null"); return .null
        case 45, 48 ... 57: return .number(try number())
        default: throw NovaAuthError.invalidResponse
        }
    }

    mutating func skipWhitespace() {
        while index < bytes.count, [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
    }

    mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    mutating func object(depth: Int) throws -> NovaAuthJSON {
        guard depth <= 4 else { throw NovaAuthError.invalidResponse }
        index += 1
        skipWhitespace()
        var result: [String: NovaAuthJSON] = [:]
        if consume(125) { return .object(result) }
        while true {
            let key = try string()
            guard result[key] == nil else { throw NovaAuthError.invalidResponse }
            skipWhitespace()
            guard consume(58) else { throw NovaAuthError.invalidResponse }
            result[key] = try value(depth: depth)
            skipWhitespace()
            if consume(125) { return .object(result) }
            guard consume(44) else { throw NovaAuthError.invalidResponse }
            skipWhitespace()
        }
    }

    mutating func array(depth: Int) throws -> NovaAuthJSON {
        guard depth <= 4 else { throw NovaAuthError.invalidResponse }
        index += 1
        skipWhitespace()
        var result: [NovaAuthJSON] = []
        if consume(93) { return .array(result) }
        while true {
            result.append(try value(depth: depth))
            skipWhitespace()
            if consume(93) { return .array(result) }
            guard consume(44) else { throw NovaAuthError.invalidResponse }
        }
    }

    mutating func string() throws -> String {
        let start = index
        guard consume(34) else { throw NovaAuthError.invalidResponse }
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if byte == 34 {
                do {
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start ..< index]))
                } catch { throw NovaAuthError.invalidResponse }
            }
            guard byte >= 32 else { throw NovaAuthError.invalidResponse }
            if byte == 92 {
                guard index < bytes.count else { throw NovaAuthError.invalidResponse }
                index += 1
            }
        }
        throw NovaAuthError.invalidResponse
    }

    mutating func number() throws -> String {
        let start = index
        _ = consume(45)
        guard index < bytes.count else { throw NovaAuthError.invalidResponse }
        if !consume(48) {
            guard (49 ... 57).contains(bytes[index]) else { throw NovaAuthError.invalidResponse }
            while index < bytes.count, (48 ... 57).contains(bytes[index]) { index += 1 }
        }
        if consume(46) { try digits() }
        if consume(101) || consume(69) {
            if !consume(43) { _ = consume(45) }
            try digits()
        }
        guard let value = String(bytes: bytes[start ..< index], encoding: .utf8) else {
            throw NovaAuthError.invalidResponse
        }
        return value
    }

    mutating func digits() throws {
        let start = index
        while index < bytes.count, (48 ... 57).contains(bytes[index]) { index += 1 }
        guard index > start else { throw NovaAuthError.invalidResponse }
    }

    mutating func literal(_ value: String) throws {
        let expected = Array(value.utf8)
        guard index + expected.count <= bytes.count,
              Array(bytes[index ..< (index + expected.count)]) == expected else { throw NovaAuthError.invalidResponse }
        index += expected.count
    }
}
