import Foundation

extension URL {
    static func twitterAddress(for account: String) -> URL? {
        URL(string: "https://twitter.com/\(account)")
    }

    static func riotAddress(for name: String) -> URL? {
        URL(string: "https://matrix.to/#/\(name)")
    }

    static func hostsEqual(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let host = lhs.host, let otherHost = rhs.host else {
            return false
        }

        return host.caseInsensitiveCompare(otherHost) == .orderedSame
    }

    static func hasSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme == rhs.scheme && lhs.host == rhs.host && lhs.port == rhs.port
    }

    func isSameUniversalLinkDomain(_ other: URL) -> Bool {
        scheme == other.scheme && host == other.host
    }
}
