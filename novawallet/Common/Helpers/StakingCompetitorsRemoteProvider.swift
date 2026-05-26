import Foundation

/// In-memory cache of third-party staking-dashboard domains fetched from nova-utils.
/// `isStakingCompetitor` is synchronous (reads the cache) so it can be called from
/// any context — including the routing path that needs an immediate decision.
/// Fail-open: a failed fetch leaves the cache empty, meaning no warnings fire
/// rather than blocking all navigation.
final class StakingCompetitorsRemoteProvider {
    static let shared = StakingCompetitorsRemoteProvider(
        url: ApplicationConfig.shared.stakingCompetitorsURL,
        session: .shared
    )

    private let url: URL
    private let session: URLSession
    private let queue = DispatchQueue(label: "io.novawallet.StakingCompetitorsRemoteProvider", attributes: .concurrent)
    private var _domains: [String] = []
    private var domains: [String] {
        queue.sync { _domains }
    }

    init(url: URL, session: URLSession) {
        self.url = url
        self.session = session
    }

    func isStakingCompetitor(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let snapshot = domains
        for domain in snapshot {
            let lowered = domain.lowercased()
            if host == lowered || host.hasSuffix("." + lowered) {
                return true
            }
        }
        return false
    }

    func sync() async {
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(StakingCompetitorsResponse.self, from: data)
            queue.async(flags: .barrier) { [weak self] in
                self?._domains = response.domains
            }
        } catch {
            // Fail-open: log and leave the cache untouched.
            Logger.shared.warning("StakingCompetitorsRemoteProvider sync failed: \(error)")
        }
    }

    /// Test-only seam. Production code must use `sync()`.
    func injectDomainsForTesting(_ domains: [String]) {
        queue.async(flags: .barrier) { [weak self] in
            self?._domains = domains
        }
        // Wait for the barrier to drain so synchronous reads in tests see the new value.
        queue.sync(flags: .barrier) {}
    }
}
