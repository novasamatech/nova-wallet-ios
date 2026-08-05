import Foundation

enum DAppStakingDetection {
    // Latin/Cyrillic keywords are matched as token prefixes so that "staking", "staker",
    // "стейкинг" match while "mistake" does not; CJK scripts have no word boundaries,
    // so full terms are matched as substrings
    private static let stakingTokenPrefixes = ["stak", "стейк"]
    private static let stakingSubstrings = ["质押", "質押", "ステーキング", "스테이킹"]

    static func isStakingQuery(_ query: String?) -> Bool {
        guard let query, !query.isEmpty else {
            return false
        }

        let normalizedQuery = query.lowercased()

        let tokens = normalizedQuery.components(separatedBy: CharacterSet.alphanumerics.inverted)

        let hasKeywordToken = tokens.contains { token in
            stakingTokenPrefixes.contains { token.hasPrefix($0) }
        }

        guard !hasKeywordToken else {
            return true
        }

        return stakingSubstrings.contains { normalizedQuery.contains($0) }
    }

    static func isThirdPartyStakingSite(
        result: DAppSearchResult,
        dAppList: DAppList?
    ) -> Bool {
        switch result {
        case let .dApp(dApp):
            return isStakingDApp(dApp) || isStakingHost(dApp.url.host)
        case let .query(query):
            // a free-text query falls back to a web search page which is not a staking site,
            // so only queries resolving to a url the same way DAppBrowserTab does are checked
            guard
                NSPredicate.urlPredicate.evaluate(with: query),
                let host = resolveHost(for: query)
            else {
                return false
            }

            return isStakingHost(host) || hasCuratedStakingDApp(withHost: host, in: dAppList)
        }
    }
}

// MARK: Private

private extension DAppStakingDetection {
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
