import Foundation

/// Thin facade over `StakingCompetitorsRemoteProvider`. Existing call sites
/// (`BrowserNavigationPresenter.routeOrWarn`, `DAppBrowserPresenter.checkStakingWarning`,
/// `DAppSearchPresenter.didReceive...`) keep the existing sync API; the domain list
/// itself is now runtime-fetched from nova-utils.
enum ThirdPartyStakingDomainMatcher {
    static func isBlocked(url: URL) -> Bool {
        StakingCompetitorsRemoteProvider.shared.isStakingCompetitor(url: url)
    }

    static func isBlocked(host: String) -> Bool {
        // Reconstruct as a URL to reuse the host-aware matching in the provider.
        guard let url = URL(string: "https://\(host)") else { return false }
        return isBlocked(url: url)
    }
}
