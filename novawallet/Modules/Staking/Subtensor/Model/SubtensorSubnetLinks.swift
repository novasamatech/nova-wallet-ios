import Foundation

struct SubtensorSubnetLinks: Equatable {
    let website: URL?
    let github: URL?

    static let empty = SubtensorSubnetLinks(website: nil, github: nil)
}

extension SubtensorSubnetLinks {
    /// The catalogue passes the owner's identity links through as raw text: no URI validation, empty strings allowed.
    init(subnetUrl: String?, subnetWebsite: String?, githubRepo: String?) {
        let websiteCandidates = [subnetUrl, subnetWebsite]

        website = websiteCandidates
            .compactMap(SubtensorSubnetLinkNormalizer.website(from:))
            .first { !SubtensorSubnetLinkNormalizer.isGithub($0) }
        github = ([githubRepo] + websiteCandidates)
            .compactMap(SubtensorSubnetLinkNormalizer.github(from:))
            .first
    }
}

enum SubtensorSubnetLinkNormalizer {
    private static let schemes = ["https", "http"]
    private static let githubHosts = ["github.com", "www.github.com", "m.github.com"]
    private static let githubNameCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
    )
    private static let gitSuffix = ".git"

    /// Trims, prefixes `https://` when the owner left the scheme out, and keeps only http(s) URLs with a dotted host.
    static func website(from raw: String?) -> URL? {
        guard let text = cleaned(raw) else {
            return nil
        }

        let parsedScheme = URLComponents(string: text)?.scheme
        let hasScheme = parsedScheme.map { text.dropFirst($0.count).hasPrefix("://") } ?? false
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

    /// Keeps `<owner>[/<repo>]` of a `github.com` link without a `.git` suffix, accepting only plain names checked
    /// before percent-decoding; the result is canonical https without a trailing slash.
    static func github(from raw: String?) -> URL? {
        guard
            let url = website(from: raw),
            isGithub(url),
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else {
            return nil
        }

        var parts = path.split(separator: "/").prefix(2).map(String.init)

        if parts.count == 2, parts[1].hasSuffix(gitSuffix) {
            parts[1].removeLast(gitSuffix.count)
        }

        guard !parts.isEmpty, parts.allSatisfy(isGithubName) else {
            return nil
        }

        return URL(string: "https://github.com/" + parts.joined(separator: "/"))
    }

    static func isGithub(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        return githubHosts.contains(host.hasSuffix(".") ? String(host.dropLast()) : host)
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

    private static func isGithubName(_ name: String) -> Bool {
        !["", ".", ".."].contains(name) && name.unicodeScalars.allSatisfy(githubNameCharacters.contains)
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
