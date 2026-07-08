import Foundation
import BigInt

/// Detail-screen fetch path for a coldkey's TAO/alpha stake positions.
///
/// Mirrors `SubtensorPositionCache` (used by the multistaking dashboard
/// sync services), but as a one-shot static call — the in-app TAO Staking
/// dashboard doesn't need cross-service deduplication, just a fresh fetch
/// each time the screen re-appears. The actual SCALE decoding lives in
/// `SubtensorStakeInfoDecoder` so a Subtensor runtime upgrade only has to
/// touch one file.
enum SubtensorPositionFetcher {
    enum FetchError: Error {
        case invalidResponse
    }

    /// Returns all non-zero stake positions for `coldkey` across every
    /// (hotkey, netuid) tuple — root + every subnet, V1 + V2 alpha
    /// storage — via Bittensor's `StakeInfoRuntimeApi`. The runtime
    /// resolves the amounts; we just decode the response.
    ///
    /// `rpcURL` should come from the chain's configured node list so dev
    /// / staging / custom-node setups don't silently fall back to mainnet.
    static func fetchPositions(coldkey: AccountId, rpcURL: URL) async throws -> [SubtensorRawPosition] {
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

        return SubtensorStakeInfoDecoder.decode(hex: hex).compactMap { entry -> SubtensorRawPosition? in
            guard entry.stake > 0 else { return nil }
            return SubtensorRawPosition(
                hotkey: entry.hotkey,
                netuid: entry.netuid,
                amount: entry.stake
            )
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
            throw FetchError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidResponse
        }
        return json["result"] as? String
    }
}

// MARK: - Model

/// A resolved stake position with the actual computed alpha/TAO amount.
struct SubtensorRawPosition {
    /// Validator hotkey.
    let hotkey: AccountId
    /// Subnet identifier (0 = root).
    let netuid: UInt16
    /// Resolved amount in the subnet's smallest unit
    /// (RAO for root, alpha-unit for subnets).
    let amount: BigUInt
}
