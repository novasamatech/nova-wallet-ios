import Foundation
import BigInt

/// Coordinates validator fetching and stake-position queries for TAO staking.
final class SubtensorStakingService {
    private let validatorProvider: SubtensorValidatorProvider
    private let selectedColdkey: AccountId
    private let rpcURL: URL

    init(
        validatorProvider: SubtensorValidatorProvider,
        selectedColdkey: AccountId,
        rpcURL: URL
    ) {
        self.validatorProvider = validatorProvider
        self.selectedColdkey = selectedColdkey
        self.rpcURL = rpcURL
    }

    /// Returns active validators for the given netuid. Pass 0 for root.
    func fetchActiveValidators(netuid: UInt16) async throws -> [SubtensorValidator] {
        try await validatorProvider.fetchValidators(netuid: netuid)
    }

    /// Returns the user's current stake positions across all hotkeys and netuids.
    /// Backed by `StakeInfoRuntimeApi_get_stake_info_for_coldkey` — the
    /// runtime aggregates everything (root TAO + every subnet, V1 + V2
    /// alpha storage) and returns resolved amounts.
    func fetchUserStakePositions() async throws -> [SubtensorStakePosition] {
        let rawPositions = try await SubtensorPositionFetcher.fetchPositions(
            coldkey: selectedColdkey,
            rpcURL: rpcURL
        )
        guard !rawPositions.isEmpty else { return [] }

        // Best-effort: load validator identities for display names.
        let validators = (try? await validatorProvider.fetchValidators(netuid: SubtensorStakingConstants.rootNetuid)) ?? []
        let identityMap: [AccountId: String] = Dictionary(
            validators.compactMap { validator -> (AccountId, String)? in
                guard let name = validator.identity, !name.isEmpty else { return nil }
                return (validator.hotkey, name)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return rawPositions.map { raw in
            SubtensorStakePosition(
                coldkey: selectedColdkey,
                hotkey: raw.hotkey,
                netuid: raw.netuid,
                amount: raw.amount,
                validatorIdentity: identityMap[raw.hotkey]
            )
        }
    }

    /// Returns the runtime minimum delegation amount in RAO (0.01 TAO).
    /// Hardcoded against the verified-live value for finney mainnet
    /// (2026-04-13). The Setup screen uses this on its "Minimum stake"
    /// row; the dashboard surfaces the same value as a static string in
    /// its info card and does not call this method.
    func fetchMinDelegation() async throws -> BigUInt {
        10_000_000
    }
}
