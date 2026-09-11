import Foundation

public enum AttestationRequestTargetError: Error {
    case unsupportedScheme
    case invalidAuthority
    case invalidPath
}

/// The frozen HTTP target a proof is issued for.
///
/// The caller builds one and uses it both to construct the request and to ask for a proof, so the
/// bytes that are sent and the bytes that are attested cannot drift apart. The fields are the ones
/// the gateway signs — method, origin, path and content type — split the way its canonical form
/// needs them rather than the way `URL` happens to store them.
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

        guard
            let scheme = components.scheme?.lowercased(),
            let defaultPort = Self.defaultPort(for: scheme)
        else {
            throw AttestationRequestTargetError.unsupportedScheme
        }

        guard let host = components.host?.lowercased(), Self.isCanonical(host: host) else {
            throw AttestationRequestTargetError.invalidAuthority
        }

        let path = components.percentEncodedPath

        guard Self.isCanonical(path: path) else {
            throw AttestationRequestTargetError.invalidPath
        }

        let effectivePort = components.port ?? defaultPort

        self.url = url
        self.method = method.uppercased()
        self.scheme = scheme
        authority = effectivePort == defaultPort ? host : host + ":" + String(effectivePort)
        port = String(effectivePort)
        self.path = path
        self.contentType = contentType
    }
}

// MARK: - Canonical origin

public extension AttestationRequestTarget {
    /// `scheme://host[:port]`, carrying the port only when it is not the scheme's default — the
    /// spelling the gateway signs. Nil when the URL cannot be addressed that way.
    static func origin(of url: URL) -> String? {
        try? AttestationRequestTarget(
            url: url,
            method: "GET",
            contentType: ""
        ).origin
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
