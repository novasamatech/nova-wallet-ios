import Foundation

enum DAppStakingSiteKind: Equatable {
    case none
    case thirdPartyStaking
    case bittensor
}

enum DAppStakingQueryKind: Equatable {
    case none
    case staking
    case bittensor
}

enum DAppStakingDetection {
    // Latin/Cyrillic keywords are matched as token prefixes so that "staking", "staker",
    // "стейкинг" match while "mistake" does not; CJK scripts have no word boundaries,
    // so full terms are matched as substrings
    private static let stakingTokenPrefixes = ["stak", "стейк"]
    private static let stakingSubstrings = ["质押", "質押", "ステーキング", "스테이킹"]

    // The expression is shared with Android and the product spec and must stay verbatim:
    // a host label (or a query word) that starts or ends with "tao" or is one of the known
    // Bittensor names, "taobao" excluded
    private static let bittensorExpression = try? NSRegularExpression(
        pattern: #"(?:^|\.)(?!taobao(?:\.|$))(?:tao[a-z0-9-]*|[a-z0-9-]*tao|bittensor|opentensor"#
            + #"|tensorwallet|tensorplex|mentat[a-z0-9-]*|backprop[a-z0-9-]*)(?=\.|$)"#,
        options: [.caseInsensitive]
    )

    static func isStakingQuery(_ query: String?) -> Bool {
        guard let query, !query.isEmpty else {
            return false
        }

        let normalizedQuery = query.lowercased()

        let hasKeywordToken = tokens(of: query).contains { token in
            stakingTokenPrefixes.contains { token.hasPrefix($0) }
        }

        guard !hasKeywordToken else {
            return true
        }

        return stakingSubstrings.contains { normalizedQuery.contains($0) }
    }

    static func isBittensorQuery(_ query: String?) -> Bool {
        guard let query, !query.isEmpty else {
            return false
        }

        return tokens(of: query).contains { matchesBittensorExpression($0) }
    }

    static func queryKind(_ query: String?) -> DAppStakingQueryKind {
        if isBittensorQuery(query) {
            return .bittensor
        }

        return isStakingQuery(query) ? .staking : .none
    }

    static func isBittensorHost(_ host: String?) -> Bool {
        guard let host, !host.isEmpty else {
            return false
        }

        return matchesBittensorExpression(host)
    }

    static func isBittensorSite(result: DAppSearchResult) -> Bool {
        isBittensorHost(siteHost(for: result))
    }

    // Bittensor is checked first so that a TAO site never gets the generic staking notice
    static func stakingSiteKind(
        result: DAppSearchResult,
        dAppList: DAppList?
    ) -> DAppStakingSiteKind {
        guard !isBittensorSite(result: result) else {
            return .bittensor
        }

        let isThirdPartyStaking = switch result {
        case let .dApp(dApp):
            isStakingDApp(dApp) || isStakingHost(dApp.url.host)
        case .query:
            siteHost(for: result).map { host in
                isStakingHost(host) || hasCuratedStakingDApp(withHost: host, in: dAppList)
            } ?? false
        }

        return isThirdPartyStaking ? .thirdPartyStaking : .none
    }
}

// MARK: Private

private extension DAppStakingDetection {
    static func tokens(of query: String) -> [String] {
        query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
    }

    static func matchesBittensorExpression(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)

        return bittensorExpression?.firstMatch(in: string, options: [], range: range) != nil
    }

    static func siteHost(for result: DAppSearchResult) -> String? {
        switch result {
        case let .dApp(dApp):
            return dApp.url.host
        case let .query(query):
            // a free-text query falls back to a web search page which is not a site of its own,
            // so only queries resolving to a url the same way DAppBrowserTab does have a host
            guard NSPredicate.urlPredicate.evaluate(with: query) else {
                return nil
            }

            return resolveHost(for: query)
        }
    }

    static func isStakingDApp(_ dApp: DApp) -> Bool {
        dApp.categories.contains(KnownDAppCategory.staking.rawValue)
    }

    static func isStakingHost(_ host: String?) -> Bool {
        guard let host else {
            return false
        }

        let labels = host.lowercased().components(separatedBy: ".")

        return labels.contains { label in
            stakingTokenPrefixes.contains { label.hasPrefix($0) }
        }
    }

    static func hasCuratedStakingDApp(withHost host: String, in dAppList: DAppList?) -> Bool {
        guard let dAppList else {
            return false
        }

        let normalizedHost = normalized(host: host)

        return dAppList.dApps.contains { dApp in
            isStakingDApp(dApp) && dApp.url.host.map { normalized(host: $0) } == normalizedHost
        }
    }

    static func normalized(host: String) -> String {
        let lowercasedHost = host.lowercased()

        return lowercasedHost.hasPrefix("www.")
            ? String(lowercasedHost.dropFirst("www.".count))
            : lowercasedHost
    }

    static func resolveHost(for query: String) -> String? {
        var urlComponents = URLComponents(string: query)

        if urlComponents?.scheme == nil {
            urlComponents = URLComponents(string: "https://" + query)
        }

        return urlComponents?.host
    }
}
