import Foundation

enum ThirdPartyStakingDomainMatcher {
    private static let blockedDomains: Set<String> = [
        "staking.polkadot.cloud",
        "polkadot.cloud",
        "app.bifrost.io",
        "omni.ls",
        "portal.invarch.network",
        "capitaldex.exchange",
        "unique.network",
        "apps.karura.network",
        "apps.acala.network",
        "farm.acala.network",
        "hub.ternoa.network",
        "mentatminds.com",
        "dash.taostats.io",
        "tensorwallet.ca",
        "staking.polkadot.network"
    ]

    static func isBlocked(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        return isBlocked(host: host)
    }

    static func isBlocked(host: String) -> Bool {
        let lowercasedHost = host.lowercased()

        for domain in blockedDomains {
            if lowercasedHost == domain || lowercasedHost.hasSuffix("." + domain) {
                return true
            }
        }

        return false
    }
}
