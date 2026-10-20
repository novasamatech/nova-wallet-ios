import Foundation

struct SubtensorSubnetLinks: Equatable {
    let website: URL?
    let github: URL?

    static let empty = SubtensorSubnetLinks(website: nil, github: nil)
}

extension SubtensorSubnetLinks {
    /// The catalogue passes the owner's identity links through as raw text: no URI validation, empty strings allowed.
    init(subnetUrl: String?, subnetWebsite: String?, githubRepo: String?) {
        website = SubtensorSubnetLinkNormalizer.website(from: subnetUrl)
            ?? SubtensorSubnetLinkNormalizer.website(from: subnetWebsite)
        github = SubtensorSubnetLinkNormalizer.github(from: githubRepo)
    }
}

enum SubtensorSubnetLinkNormalizer {
    private static let schemes = ["https", "http"]
    private static let githubHosts = ["github.com", "www.github.com"]

    /// Trims, prefixes `https://` when the owner left the scheme out, and keeps only http(s) URLs with a dotted host.
    static func website(from raw: String?) -> URL? {
        guard let text = cleaned(raw) else {
            return nil
        }

        let hasScheme = URLComponents(string: text)?.scheme != nil
        let withScheme = hasScheme ? text : "https://" + text

        guard
            var components = URLComponents(string: withScheme),
            let scheme = components.scheme?.lowercased(),
            schemes.contains(scheme),
            components.user == nil,
            let host = components.host,
            host.contains(".") else {
            return nil
        }

        components.scheme = scheme

        return components.url
    }

    /// Only `github.com/<owner>[/<repo>]` counts as a repository link; the result is canonical https
    /// without a trailing slash.
    static func github(from raw: String?) -> URL? {
        guard
            let url = website(from: raw),
            let host = url.host?.lowercased(),
            githubHosts.contains(host) else {
            return nil
        }

        let parts = pathParts(of: url)

        guard (1 ... 2).contains(parts.count) else {
            return nil
        }

        return URL(string: "https://github.com/" + parts.joined(separator: "/"))
    }

    static func websiteDisplayText(_ url: URL) -> String {
        var text = url.absoluteString

        if let scheme = url.scheme, text.lowercased().hasPrefix(scheme + "://") {
            text = String(text.dropFirst(scheme.count + "://".count))
        }

        while text.hasSuffix("/") {
            text.removeLast()
        }

        return text
    }

    static func githubDisplayText(_ url: URL) -> String {
        pathParts(of: url).joined(separator: "/")
    }

    private static func pathParts(of url: URL) -> [String] {
        url.pathComponents.filter { $0 != "/" }
    }

    private static func cleaned(_ raw: String?) -> String? {
        guard
            let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty,
            text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        return text
    }
}
