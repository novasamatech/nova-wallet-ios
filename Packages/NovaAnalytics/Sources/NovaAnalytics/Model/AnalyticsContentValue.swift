import Foundation

/// Content that is not a closed set still never carries free text: every factory fails on anything
/// outside its grammar, and each grammar sits inside `AnalyticsWirePayloadPolicy.grammar`.
public struct AnalyticsContentValue: Equatable {
    public enum Kind: CaseIterable {
        case assetSymbol
        case networkName
        case dappHost
        case providerId
        case bannerId
        case signingMethod
        case caip2Chain
    }

    public let kind: Kind
    public let stringValue: String

    private init(kind: Kind, stringValue: String) {
        self.kind = kind
        self.stringValue = stringValue
    }

    public static func assetSymbol(_ symbol: String) -> AnalyticsContentValue? {
        make(.assetSymbol, from: symbol)
    }

    public static func networkName(_ name: String) -> AnalyticsContentValue? {
        make(.networkName, from: name)
    }

    /// Only the host survives. Userinfo makes the whole URL a secret, so such a URL yields nothing.
    public static func dappHost(_ url: URL) -> AnalyticsContentValue? {
        guard url.user == nil, url.password == nil, let host = url.host else {
            return nil
        }

        return make(.dappHost, from: host.lowercased())
    }

    public static func providerId(_ id: String) -> AnalyticsContentValue? {
        make(.providerId, from: id)
    }

    public static func bannerId(_ id: String) -> AnalyticsContentValue? {
        make(.bannerId, from: id)
    }

    public static func signingMethod(_ method: String) -> AnalyticsContentValue? {
        make(.signingMethod, from: method)
    }

    public static func caip2Chain(_ chain: String) -> AnalyticsContentValue? {
        make(.caip2Chain, from: chain)
    }
}

extension AnalyticsContentValue.Kind {
    var grammar: AnalyticsContentGrammar {
        switch self {
        case .assetSymbol:
            return AnalyticsContentGrammar(
                alphabet: Alphabet.registryLabel,
                lengths: 1 ... 16,
                shape: Self.isSingleSpaced
            )
        case .networkName:
            return AnalyticsContentGrammar(
                alphabet: Alphabet.registryLabel,
                lengths: 1 ... 48,
                shape: Self.isSingleSpaced
            )
        case .dappHost:
            return AnalyticsContentGrammar(
                alphabet: Alphabet.lowercase.union(Alphabet.digits).union(CharacterSet(charactersIn: ".-")),
                lengths: 1 ... 64
            )
        case .providerId, .bannerId, .signingMethod:
            return AnalyticsContentGrammar(
                alphabet: Alphabet.alphanumerics.union(CharacterSet(charactersIn: "._-")),
                lengths: 1 ... 64
            )
        case .caip2Chain:
            return AnalyticsContentGrammar(
                alphabet: Alphabet.alphanumerics.union(CharacterSet(charactersIn: "-_:")),
                lengths: 5 ... 41,
                shape: Self.isCaip2
            )
        }
    }
}

private extension AnalyticsContentValue {
    static func make(_ kind: Kind, from value: String) -> AnalyticsContentValue? {
        guard kind.grammar.accepts(value) else {
            return nil
        }

        return AnalyticsContentValue(kind: kind, stringValue: value)
    }
}

private extension AnalyticsContentValue.Kind {
    typealias Alphabet = AnalyticsContentGrammar.Alphabet

    static let caip2Namespace = AnalyticsContentGrammar(
        alphabet: Alphabet.lowercase.union(Alphabet.digits).union(CharacterSet(charactersIn: "-")),
        lengths: 3 ... 8
    )

    static let caip2Reference = AnalyticsContentGrammar(
        alphabet: Alphabet.alphanumerics.union(CharacterSet(charactersIn: "-_")),
        lengths: 1 ... 32
    )

    static func isSingleSpaced(_ value: String) -> Bool {
        value.split(separator: " ", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty }
    }

    static func isCaip2(_ value: String) -> Bool {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)

        guard parts.count == 2 else {
            return false
        }

        return caip2Namespace.accepts(String(parts[0])) && caip2Reference.accepts(String(parts[1]))
    }
}
