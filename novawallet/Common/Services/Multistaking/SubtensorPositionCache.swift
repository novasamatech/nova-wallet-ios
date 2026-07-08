import Foundation
import BigInt

/// Shared per-coldkey cache of Bittensor stake positions.
///
/// `MultistakingSyncService` creates one `OnchainSyncServiceProtocol`
/// instance per (ChainAsset, StakingType) pair — for Bittensor that means
/// 129 services fire concurrently (TAO root + 128 subnet alpha assets) the
/// moment a wallet is selected. Without coordination, each would hit the
/// public RPC endpoint and most would be rate-limited. This actor folds the
/// 129 calls into one network round-trip per coldkey.
///
/// The fetch itself goes via the runtime API call
/// `state_call("StakeInfoRuntimeApi_get_stake_info_for_coldkey", coldkey)`
/// (decoder lives in `SubtensorStakeInfoDecoder`). One request returns
/// every (hotkey, netuid) the coldkey has stake in, with `stake` already
/// resolved by the runtime — no client-side share/alpha math.
actor SubtensorPositionCache {
    static let shared = SubtensorPositionCache()

    struct Position {
        let hotkey: AccountId
        let netuid: UInt16
        /// Actual alpha amount in smallest units (RAO for netuid=0, alpha-unit for netuid>0)
        let amount: BigUInt
    }

    private struct CacheEntry {
        let positions: [Position]
        let expiry: Date
    }

    private var cache: [Data: CacheEntry] = [:]
    private var inFlight: [Data: Task<[Position], Error>] = [:]
    /// Bumped on `invalidate(coldkey:)`. Each in-flight task captures the
    /// generation at start; a stale generation discards its result rather
    /// than overwriting the cleared cache with pre-stake data.
    private var generation: [Data: Int] = [:]

    private static let ttl: TimeInterval = 15

    /// Fetch positions for a coldkey. If a fetch is already in flight for this
    /// coldkey, await the same task. Otherwise start a new fetch and cache it.
    func positions(for coldkey: AccountId, rpcURL: URL) async throws -> [Position] {
        if let entry = cache[coldkey], entry.expiry > Date() {
            return entry.positions
        }

        if let task = inFlight[coldkey] {
            return try await task.value
        }

        let myGeneration = generation[coldkey, default: 0]
        let task = Task<[Position], Error> {
            try await Self.fetchAllPositions(coldkey: coldkey, rpcURL: rpcURL)
        }
        inFlight[coldkey] = task

        let result = try await task.value
        // Only persist if no `invalidate` fired during the fetch — otherwise
        // we'd repopulate the just-cleared cache with pre-stake data and
        // future readers would see stale state for the next 15s TTL.
        if generation[coldkey, default: 0] == myGeneration {
            cache[coldkey] = CacheEntry(
                positions: result,
                expiry: Date().addingTimeInterval(Self.ttl)
            )
            inFlight[coldkey] = nil
        }
        return result
    }

    /// Invalidate the cache — called after a stake/unstake extrinsic so the
    /// next sync reflects the new state immediately. We deliberately do NOT
    /// cancel `inFlight[coldkey]`: cancelling propagates `CancellationError`
    /// to up to 128 concurrent awaiters (the per-asset sync services), each
    /// of which would then surface an error on the dashboard for ~30s until
    /// the next poll cycle. Letting the in-flight finish on its own is
    /// harmless because the generation bump below makes its result a no-op
    /// for cache writes.
    ///
    /// Posts `subtensorPositionsInvalidated` so the per-netuid update
    /// services can pre-empt their 30s poll and refresh the dashboard
    /// immediately rather than leaving a stale row up for up to 30s.
    func invalidate(coldkey: AccountId) {
        cache[coldkey] = nil
        generation[coldkey, default: 0] += 1

        Task { @MainActor in
            NotificationCenter.default.post(
                name: .subtensorPositionsInvalidated,
                object: nil,
                userInfo: ["coldkey": coldkey]
            )
        }
    }

    // MARK: - Fetch implementation

    private static func fetchAllPositions(coldkey: AccountId, rpcURL: URL) async throws -> [Position] {
        let coldkeyHex = "0x" + coldkey.map { String(format: "%02x", $0) }.joined()
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "state_call",
            "params": [
                "StakeInfoRuntimeApi_get_stake_info_for_coldkey",
                coldkeyHex
            ]
        ]

        guard let hex = try await sendSingle(request: request, url: rpcURL) else {
            return []
        }

        return SubtensorStakeInfoDecoder.decode(hex: hex).compactMap { entry -> Position? in
            guard entry.stake > 0 else { return nil }
            return Position(hotkey: entry.hotkey, netuid: entry.netuid, amount: entry.stake)
        }
    }

    private static func sendSingle(request: [String: Any], url: URL) async throws -> String? {
        let body = try JSONSerialization.data(withJSONObject: request)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SubtensorCacheError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubtensorCacheError.invalidResponse
        }
        return json["result"] as? String
    }
}

private enum SubtensorCacheError: Error {
    case invalidResponse
}

extension Notification.Name {
    /// Fires from `SubtensorPositionCache.invalidate(coldkey:)`. userInfo
    /// carries `["coldkey": AccountId]` so per-netuid update services can
    /// match their own coldkey before triggering an immediate re-sync.
    static let subtensorPositionsInvalidated = Notification.Name(
        "io.novafoundation.novawallet.subtensorPositionsInvalidated"
    )
}
