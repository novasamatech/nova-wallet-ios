import Foundation
import BigInt
import NovaCrypto

/// [TEMP-TAOSTATS] Phase B data source backed by TaoStats' public REST API.
///
/// Endpoint: `https://api.taostats.io/api/validator/latest/v1?limit=200`
/// Auth: raw API key in the `Authorization` header (no `Bearer` prefix).
///
/// A single call returns all currently active validators (~75 rows), so
/// no pagination is required for v1. The actor caches the last successful
/// response for offline fallback, mirroring `BittensorDelegatesClient`.
///
/// When Nova's indexer ships Bittensor support this file is deleted and
/// `SubtensorStakeSetupViewFactory` is updated to instantiate a Nova-backed
/// `SubtensorValidatorDataSourceProtocol` implementation instead — no other
/// code change is required.
actor TaoStatsValidatorDataSource: SubtensorValidatorDataSourceProtocol {
    enum Error: Swift.Error {
        case httpStatus(Int)
        case invalidResponse(URL)
    }

    /// Generic Substrate SS58 prefix. Bittensor hotkeys use the same
    /// 42-byte generic prefix, which matches TaoStats' returned `hotkey.ss58`.
    private static let bittensorSS58Prefix: UInt16 = 42

    private static let endpointURL = URL(
        string: "https://api.taostats.io/api/validator/latest/v1?limit=200"
    )!

    private let apiKey: String
    private let session: URLSession
    private var cache: [SubtensorValidatorData] = []

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Fetches the latest validators over HTTP, parses, caches, and
    /// returns them. Throws on network failure or non-200 status. On
    /// success, rows whose `hotkey.ss58` cannot be decoded are skipped.
    func fetchValidatorData(netuid _: UInt16) async throws -> [SubtensorValidatorData] {
        var request = URLRequest(url: Self.endpointURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Error.invalidResponse(Self.endpointURL)
        }
        guard http.statusCode == 200 else {
            throw Error.httpStatus(http.statusCode)
        }

        let parsed = try Self.parse(jsonData: data)
        cache = parsed
        return parsed
    }

    /// Returns the last successfully fetched result. Empty before any
    /// fetch succeeds.
    func cachedValidatorData() -> [SubtensorValidatorData] {
        cache
    }

    // MARK: - Parsing

    /// Pure synchronous parser. Exposed so tests can verify parsing
    /// behaviour without hitting the network. Rows whose `hotkey.ss58`
    /// cannot be decoded to an `AccountId` are silently dropped.
    nonisolated static func parse(jsonData: Data) throws -> [SubtensorValidatorData] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(TaoStatsValidatorResponse.self, from: jsonData)
        let factory = SS58AddressFactory()

        return response.data.compactMap { row in
            let ss58 = row.hotkey.ss58
            guard
                let accountId = try? factory.accountId(
                    fromAddress: ss58,
                    type: bittensorSS58Prefix
                )
            else {
                return nil
            }

            let totalStake = BigUInt(row.stake ?? "") ?? 0
            let ownStake = BigUInt(row.validatorStake ?? "") ?? 0
            let commission = Double(row.take ?? "") ?? 0
            let apr: Double? = {
                if let avg = row.apr30DayAverage, let value = Double(avg), value > 0 {
                    return value
                }
                if let daily = row.apr, let value = Double(daily) {
                    return value
                }
                return nil
            }()

            let nominatorCount: UInt32? = row.nominators.flatMap { value in
                guard value >= 0 else { return nil }
                return UInt32(value)
            }

            // Prefer an explicitly non-empty name; otherwise leave nil so
            // `SubtensorValidatorProvider` can fall back to the identity
            // registry lookup.
            let trimmedName = row.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = (trimmedName?.isEmpty == false) ? trimmedName : nil

            return SubtensorValidatorData(
                hotkey: accountId,
                ss58: ss58,
                name: resolvedName,
                totalStake: totalStake,
                ownStake: ownStake,
                commission: commission,
                nominatorCount: nominatorCount,
                apr: apr
            )
        }
    }
}

// MARK: - Wire format

/// Internal DTOs matching the subset of the TaoStats v1 response we use.
/// All numeric stake fields arrive as decimal-string RAO u64; `take`,
/// `apr`, and `apr_30_day_average` arrive as decimal-string fractions.
private struct TaoStatsValidatorResponse: Decodable {
    let data: [TaoStatsValidator]
}

private struct TaoStatsValidator: Decodable {
    let hotkey: TaoStatsHotkey
    let name: String?
    let stake: String?
    let validatorStake: String?
    let take: String?
    let apr: String?
    let apr30DayAverage: String?
    let nominators: Int?

    enum CodingKeys: String, CodingKey {
        case hotkey
        case name
        case stake
        case validatorStake = "validator_stake"
        case take
        case apr
        case apr30DayAverage = "apr_30_day_average"
        case nominators
    }
}

private struct TaoStatsHotkey: Decodable {
    let ss58: String
}
