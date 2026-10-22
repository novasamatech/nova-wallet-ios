import Foundation

enum NovaAuthValidation {
    static func clientID(_ value: String) throws {
        guard let uuid = UUID(uuidString: value), uuid.uuidString.lowercased() == value,
              value.count == 36, value[value.index(value.startIndex, offsetBy: 14)] == "4",
              "89ab".contains(value[value.index(value.startIndex, offsetBy: 19)]) else {
            throw NovaAuthError.invalidRequest
        }
    }

    static func keyID(_ value: String) throws {
        guard value.utf8.count == 44, let bytes = Data(base64Encoded: value), bytes.count == 32,
              bytes.base64EncodedString() == value else { throw NovaAuthError.keyUnavailable }
    }

    static func challenge(_ value: String) throws {
        guard value.utf8.count == 43,
              value.utf8
              .allSatisfy({
                  (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57)
                      .contains($0) || $0 == 45 || $0 == 95
              }),
              let bytes = Data(
                  base64Encoded: value.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/") + "="
              ),
              bytes.count == 32,
              bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
              .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == value else {
            throw NovaAuthError.invalidResponse
        }
    }

    static func contentType(_ value: String) throws {
        guard value == "application/json" || value == "application/json; charset=utf-8" else {
            throw NovaAuthError.invalidRequest
        }
    }

    static func token(_ value: String) throws {
        guard (1 ... 3072).contains(value.utf8.count),
              value.utf8.allSatisfy({ (33 ... 126).contains($0) && $0 != 44 })
        else { throw NovaAuthError.invalidResponse }
    }

    static func lifetime(issuedAt: Int64, expiresAt: Int64, range: ClosedRange<Int64>) throws -> Int64 {
        let result = expiresAt.subtractingReportingOverflow(issuedAt)
        guard issuedAt >= 0, expiresAt >= 0, !result.overflow, range.contains(result.partialValue) else {
            throw NovaAuthError.invalidResponse
        }
        return result.partialValue
    }
}
