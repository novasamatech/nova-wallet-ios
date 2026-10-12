import Foundation
import Darwin

public struct NovaAuthOrigin: Hashable, Codable {
    public let value: String
    private let validatedURL: URL
    public var url: URL { validatedURL }

    public init(_ value: String) throws {
        guard value.hasPrefix("https://"), value.utf8.allSatisfy({ $0 < 128 }) else {
            throw NovaAuthError.invalidConfiguration
        }
        let authority = String(value.dropFirst(8))
        let parts = authority.split(separator: ":", omittingEmptySubsequences: false)
        guard (1 ... 2).contains(parts.count) else { throw NovaAuthError.invalidConfiguration }
        let host = parts[0]
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !host.isEmpty, host.utf8.count <= 253,
              !host.utf8.allSatisfy({ (48 ... 57).contains($0) || $0 == 46 }),
              labels.allSatisfy({ label in
                  (1 ... 63).contains(label.utf8.count) && label.first != "-" && label.last != "-" &&
                      label.utf8.allSatisfy { (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45 }
              }) else { throw NovaAuthError.invalidConfiguration }
        var address = in_addr()
        guard inet_aton(String(host), &address) == 0 else { throw NovaAuthError.invalidConfiguration }
        if parts.count == 2 {
            let port = parts[1]
            guard let number = UInt16(port), number > 0, number != 443,
                  String(number) == port else { throw NovaAuthError.invalidConfiguration }
        }
        guard let url = URL(string: value), url.absoluteString == value else {
            throw NovaAuthError.invalidConfiguration
        }
        self.value = value
        validatedURL = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
