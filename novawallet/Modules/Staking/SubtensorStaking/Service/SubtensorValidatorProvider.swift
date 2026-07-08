import Foundation
import BigInt

/// Fetches Bittensor validators for a given netuid, merging identity
/// metadata from the bittensor-delegates registry with numeric data
/// (stake / commission / APR / nominator counts) obtained from a
/// pluggable `SubtensorValidatorDataSourceProtocol` implementation.
///
/// Phase B wires a TaoStats-backed data source; a future Nova-indexer
/// implementation will drop in via a one-line DI change in
/// `SubtensorStakeSetupViewFactory`. The provider itself is data-source
/// agnostic — it merges identity + numeric records by SS58 string.
final class SubtensorValidatorProvider {
    private let delegatesClient: BittensorDelegatesClient
    private let dataSource: SubtensorValidatorDataSourceProtocol

    init(
        delegatesClient: BittensorDelegatesClient,
        dataSource: SubtensorValidatorDataSourceProtocol
    ) {
        self.delegatesClient = delegatesClient
        self.dataSource = dataSource
    }

    /// Returns active validators on the given netuid, sorted by total stake
    /// descending with a secondary alpha sort on identity.
    ///
    /// Flow:
    /// 1. Fetch delegates identity + numeric data concurrently.
    /// 2. If numeric data came back with rows, emit one `SubtensorValidator`
    ///    per numeric row and merge name/url/description from the identity
    ///    registry by SS58.
    /// 3. If numeric data came back empty but delegates is populated, emit
    ///    identity-only rows with zero numeric values (preserves the
    ///    Phase A stub behaviour for DEBUG builds without an API key and
    ///    for all release builds).
    func fetchValidators(netuid: UInt16) async throws -> [SubtensorValidator] {
        async let delegatesTask = fetchDelegatesWithFallback()
        async let dataTask = fetchValidatorDataWithFallback(netuid: netuid)

        let delegates = try await delegatesTask
        let validatorData = await dataTask

        let minDelegation = await fetchMinDelegation()

        var validators: [SubtensorValidator] = []

        if !validatorData.isEmpty {
            for row in validatorData {
                let metadata = delegates[row.ss58]
                let identity = row.name ?? metadata?.name
                let delegated = row.totalStake > row.ownStake
                    ? row.totalStake - row.ownStake
                    : 0

                validators.append(
                    SubtensorValidator(
                        hotkey: row.hotkey,
                        netuid: netuid,
                        identity: identity,
                        url: metadata?.url,
                        description: metadata?.description,
                        totalStake: row.totalStake,
                        ownStake: row.ownStake,
                        delegatedStake: delegated,
                        commission: row.commission,
                        nominatorCount: row.nominatorCount,
                        minDelegation: minDelegation,
                        apr: row.apr
                    )
                )
            }
        } else {
            for (ss58, metadata) in delegates {
                let hotkey = Self.placeholderAccountId(for: ss58)
                validators.append(
                    SubtensorValidator(
                        hotkey: hotkey,
                        netuid: netuid,
                        identity: metadata.name,
                        url: metadata.url,
                        description: metadata.description,
                        totalStake: 0,
                        ownStake: 0,
                        delegatedStake: 0,
                        commission: 0.0,
                        nominatorCount: nil,
                        minDelegation: minDelegation,
                        apr: nil
                    )
                )
            }
        }

        return validators.sorted { lhs, rhs in
            if lhs.totalStake != rhs.totalStake {
                return lhs.totalStake > rhs.totalStake
            }
            return (lhs.identity ?? "") < (rhs.identity ?? "")
        }
    }

    // MARK: - Concurrency helpers

    private func fetchDelegatesWithFallback() async throws -> [String: BittensorDelegateMetadata] {
        do {
            return try await delegatesClient.fetchDelegates()
        } catch {
            // Offline fallback: use the last-known cache. Empty if never fetched.
            let cached = await delegatesClient.cachedDelegates()
            if cached.isEmpty {
                throw error
            }
            return cached
        }
    }

    private func fetchValidatorDataWithFallback(netuid: UInt16) async -> [SubtensorValidatorData] {
        do {
            return try await dataSource.fetchValidatorData(netuid: netuid)
        } catch {
            // Soft-fail: fall through to identity-only rows. Upstream error
            // reporting is the delegates client's job; losing numeric data
            // is a graceful degradation, not a user-facing failure.
            return []
        }
    }

    // MARK: - Identity-only fallback

    /// Deterministic pseudo-`AccountId` used when the numeric data source
    /// returns no rows and we emit identity-only placeholder validators.
    /// NOT cryptographically meaningful — the real `AccountId` is produced
    /// by the data source's SS58 decode when numeric data is available.
    private static func placeholderAccountId(for ss58: String) -> AccountId {
        var bytes = [UInt8](repeating: 0, count: 32)
        for (index, byte) in ss58.utf8.enumerated() {
            bytes[index % 32] ^= byte
        }
        return Data(bytes)
    }

    /// Known mainnet value — verified against live chain 2026-04-13.
    private func fetchMinDelegation() async -> BigUInt {
        10_000_000 // 0.01 TAO in RAO
    }
}
