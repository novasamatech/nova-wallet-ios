import Foundation

public enum AttestationRequestTargetError: Error {
    case unsupportedScheme
    case invalidAuthority
    case invalidPath
}

/// Use the same target to construct the HTTP request and its proof so their signed fields match.
public struct AttestationRequestTarget: Equatable {
    public let url: URL
    public let method: String
    public let scheme: String
    public let authority: String
    public let port: String
    public let path: String
    public let contentType: String

    public var origin: String { scheme + "://" + authority }

    public init(url: URL, method: String, contentType: String) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AttestationRequestTargetError.invalidAuthority
        }

        guard let scheme = components.scheme?.lowercased(), Self.defaultPort(for: scheme) != nil else {
            throw AttestationRequestTargetError.unsupportedScheme
        }

        guard let authority = Self.canonicalAuthority(scheme: scheme, components: components) else {
            throw AttestationRequestTargetError.invalidAuthority
        }

        let path = components.percentEncodedPath

        guard Self.isCanonical(path: path) else {
            throw AttestationRequestTargetError.invalidPath
        }

        self.url = url
        self.method = method.uppercased()
        self.scheme = scheme
        self.authority = authority.value
        port = String(authority.port)
        self.path = path
        self.contentType = contentType
    }
}

// MARK: - Canonical origin

public extension AttestationRequestTarget {
    /// Returns `scheme://host[:port]` with default ports omitted, or nil for an unsupported origin.
    /// The path does not affect the result.
    static func origin(of url: URL) -> String? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            let authority = canonicalAuthority(scheme: scheme, components: components)
        else {
            return nil
        }

        return scheme + "://" + authority.value
    }
}

// MARK: - Private

private extension AttestationRequestTarget {
    static let hostAlphabet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
    static let pathAlphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        .union(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789/._~-"))

    static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "https": 443
        case "http": 80
        default: nil
        }
    }

    // Share normalization so origin validation and proof construction compare identical strings.
    static func canonicalAuthority(
        scheme: String,
        components: URLComponents
    ) -> (value: String, port: Int)? {
        guard
            let defaultPort = defaultPort(for: scheme),
            let host = components.host?.lowercased(),
            isCanonical(host: host)
        else {
            return nil
        }

        let port = components.port ?? defaultPort

        return (port == defaultPort ? host : host + ":" + String(port), port)
    }

    static func isCanonical(host: String) -> Bool {
        guard
            !host.isEmpty,
            host.utf8.count <= 253,
            host.unicodeScalars.allSatisfy(hostAlphabet.contains)
        else {
            return false
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)

        return labels.allSatisfy { label in
            guard 1 ... 63 ~= label.count else {
                return false
            }

            return label.first != "-" && label.last != "-"
        }
    }

    static func isCanonical(path: String) -> Bool {
        guard
            path.hasPrefix("/"),
            !path.contains("//"),
            path.unicodeScalars.allSatisfy(pathAlphabet.contains)
        else {
            return false
        }

        return !path.split(separator: "/").contains { $0 == "." || $0 == ".." }
    }
}
