import Foundation

struct BittensorDelegateMetadata: Decodable {
    let name: String
    let url: String?
    let description: String?
    let signature: String?
}

/// Fetches and parses the opentensor/bittensor-delegates registry for
/// validator identity metadata. Does NOT fetch stake / commission /
/// nominator counts — those come from on-chain queries in
/// SubtensorValidatorProvider.
///
/// The keys in the returned dictionary are SS58 addresses (strings).
/// Upstream code converts them to AccountId when matching on-chain data.
actor BittensorDelegatesClient {
    enum Error: Swift.Error {
        case httpStatus(Int)
        case invalidResponse(URL)
    }

    private let session: URLSession
    private var cache: [String: BittensorDelegateMetadata] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the registry over HTTP, parses it, caches the result, and
    /// returns it. Throws on network failure, non-200 status, or parse failure.
    func fetchDelegates() async throws -> [String: BittensorDelegateMetadata] {
        let (data, response) = try await session.data(
            from: SubtensorStakingConstants.delegatesRegistryURL
        )
        guard let http = response as? HTTPURLResponse else {
            throw Error.invalidResponse(SubtensorStakingConstants.delegatesRegistryURL)
        }
        guard http.statusCode == 200 else {
            throw Error.httpStatus(http.statusCode)
        }

        let parsed = try Self.parse(jsonData: data)
        cache = parsed
        return parsed
    }

    /// Pure synchronous parser. Exposed so tests can verify parsing
    /// behavior without hitting the network.
    nonisolated static func parse(jsonData: Data) throws -> [String: BittensorDelegateMetadata] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: BittensorDelegateMetadata].self, from: jsonData)
    }

    /// Returns the last successfully fetched registry. Empty before any
    /// fetch succeeds. Useful for offline-mode fallback in the provider.
    func cachedDelegates() -> [String: BittensorDelegateMetadata] {
        cache
    }
}
