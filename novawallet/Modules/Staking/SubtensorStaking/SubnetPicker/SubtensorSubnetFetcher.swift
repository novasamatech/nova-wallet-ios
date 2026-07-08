import Foundation
import xxHash_Swift
import SubstrateSdk

/// Fetches subnet metadata from the Bittensor chain via direct HTTP
/// JSON-RPC calls using URLSession. Queries SubnetTAO, SubnetAlphaIn,
/// and SubnetIdentitiesV3 storage items for all active subnets.
///
/// Uses HTTP POST to the chain's RPC endpoint — no dependency on Nova's
/// internal WebSocket engine. Same pattern as BittensorDelegatesClient.
actor SubtensorSubnetFetcher {
    enum FetchError: Error {
        case noRPCEndpoint
        case rpcError(String)
        case invalidResponse
    }

    // Use the first available HTTP endpoint for Bittensor.
    // The WSS entrypoint also accepts HTTPS on port 443.
    private static let rpcURL = URL(string: "https://entrypoint-finney.opentensor.ai")!

    /// Fetches all active subnets with names and AMM reserves.
    static func fetchAllSubnets(chainId _: String) async throws -> [SubtensorSubnetInfo] {
        var subnets: [SubtensorSubnetInfo] = []

        // Fetch reserves and names concurrently for netuids 1...128
        // Use a batch RPC call to minimize round-trips
        let batchSize = 128
        var requests: [[String: Any]] = []

        for netuid: UInt16 in 1 ... UInt16(batchSize) {
            let netuidLE = Data([UInt8(netuid & 0xFF), UInt8(netuid >> 8)])

            let taoKey = storageKey(module: "SubtensorModule", item: "SubnetTAO", mapKey: netuidLE, hasher: .identity)
            let alphaKey = storageKey(module: "SubtensorModule", item: "SubnetAlphaIn", mapKey: netuidLE, hasher: .identity)
            let nameKey = storageKey(module: "SubtensorModule", item: "SubnetIdentitiesV3", mapKey: netuidLE, hasher: .blake2b128Concat)

            let baseId = Int(netuid) * 3
            requests.append(rpcRequest(id: baseId, method: "state_getStorage", params: [taoKey]))
            requests.append(rpcRequest(id: baseId + 1, method: "state_getStorage", params: [alphaKey]))
            requests.append(rpcRequest(id: baseId + 2, method: "state_getStorage", params: [nameKey]))
        }

        let responses = try await sendBatchRPC(requests: requests)

        for netuid: UInt16 in 1 ... UInt16(batchSize) {
            let baseId = Int(netuid) * 3
            let taoHex = responses[baseId] ?? nil
            let alphaHex = responses[baseId + 1] ?? nil
            let nameHex = responses[baseId + 2] ?? nil

            let taoReserve = decodeU64LE(hex: taoHex)
            let alphaIn = decodeU64LE(hex: alphaHex)

            guard taoReserve > 0 else { continue }

            let name: String? = extractSubnetName(from: nameHex)

            subnets.append(SubtensorSubnetInfo(
                netuid: netuid,
                name: name,
                taoReserve: taoReserve,
                alphaInReserve: alphaIn
            ))
        }

        return subnets
    }

    // MARK: - Storage key building

    private static func storageKey(
        module: String,
        item: String,
        mapKey: Data,
        hasher: Hasher
    ) -> String {
        let moduleHash = twox128(module.data(using: .utf8)!)
        let itemHash = twox128(item.data(using: .utf8)!)

        let keyHash: Data
        switch hasher {
        case .twox64Concat:
            keyHash = twox64(mapKey) + mapKey
        case .blake2b128Concat:
            keyHash = blake2_128(mapKey) + mapKey
        case .identity:
            keyHash = mapKey
        }

        return "0x" + (moduleHash + itemHash + keyHash).map { String(format: "%02x", $0) }.joined()
    }

    private enum Hasher {
        case twox64Concat
        case blake2b128Concat
        case identity
    }

    // MARK: - Hash functions

    private static func twox128(_ data: Data) -> Data {
        var h0 = XXH64.digest(data, seed: 0)
        var h1 = XXH64.digest(data, seed: 1)
        return Data(bytes: &h0, count: 8) + Data(bytes: &h1, count: 8)
    }

    private static func twox64(_ data: Data) -> Data {
        var h0 = XXH64.digest(data, seed: 0)
        return Data(bytes: &h0, count: 8)
    }

    private static func blake2_128(_ data: Data) -> Data {
        // SubstrateSdk's Data.blake2b16() returns blake2b with 16-byte (128-bit) output
        (try? data.blake2b16()) ?? Data(count: 16)
    }

    // MARK: - RPC helpers

    private static func rpcRequest(id: Int, method: String, params: [Any]) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ]
    }

    private static func sendBatchRPC(requests: [[String: Any]]) async throws -> [Int: String?] {
        let jsonData = try JSONSerialization.data(withJSONObject: requests)

        var urlRequest = URLRequest(url: rpcURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.invalidResponse
        }

        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FetchError.invalidResponse
        }

        var results: [Int: String?] = [:]
        for item in array {
            guard let id = item["id"] as? Int else { continue }
            results[id] = item["result"] as? String
        }

        return results
    }

    // MARK: - Decoders

    private static func decodeU64LE(hex: String?) -> UInt64 {
        guard let hex = hex, hex.count > 2 else { return 0 }
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard clean.count >= 16 else { return 0 }

        var bytes = [UInt8]()
        var idx = clean.startIndex
        for _ in 0 ..< 8 {
            let end = clean.index(idx, offsetBy: 2)
            if let byte = UInt8(clean[idx ..< end], radix: 16) {
                bytes.append(byte)
            }
            idx = end
        }

        guard bytes.count == 8 else { return 0 }
        return bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        }
    }

    private static func extractSubnetName(from hexValue: String?) -> String? {
        guard let hex = hexValue, hex.count > 4 else { return nil }
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex

        var bytes = [UInt8]()
        var idx = clean.startIndex
        while idx < clean.endIndex {
            let end = clean.index(idx, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            if let byte = UInt8(clean[idx ..< end], radix: 16) {
                bytes.append(byte)
            }
            idx = end
        }

        guard bytes.count > 1 else { return nil }

        // SCALE compact-encoded length prefix for the first field (subnet_name: Vec<u8>)
        let first = bytes[0]
        let mode = first & 0b11
        let nameStart: Int
        let nameLength: Int

        switch mode {
        case 0b00:
            nameLength = Int(first >> 2)
            nameStart = 1
        case 0b01:
            guard bytes.count > 1 else { return nil }
            let val = UInt16(first) | (UInt16(bytes[1]) << 8)
            nameLength = Int(val >> 2)
            nameStart = 2
        default:
            return nil
        }

        guard nameLength > 0, nameLength <= 128, nameStart + nameLength <= bytes.count else {
            return nil
        }

        return String(data: Data(bytes[nameStart ..< nameStart + nameLength]), encoding: .utf8)
    }
}

// MARK: - Single-subnet reserve query

struct SubtensorSubnetReserves {
    let netuid: UInt16
    let taoReserve: UInt64
    let alphaInReserve: UInt64
}

extension SubtensorSubnetFetcher {
    /// Fetches TAO and alpha-in reserves for a single subnet.
    static func fetchSubnetReserves(netuid: UInt16) async throws -> SubtensorSubnetReserves {
        let netuidLE = Data([UInt8(netuid & 0xFF), UInt8(netuid >> 8)])

        let taoKey = storageKey(module: "SubtensorModule", item: "SubnetTAO", mapKey: netuidLE, hasher: .identity)
        let alphaKey = storageKey(module: "SubtensorModule", item: "SubnetAlphaIn", mapKey: netuidLE, hasher: .identity)

        let requests: [[String: Any]] = [
            rpcRequest(id: 1, method: "state_getStorage", params: [taoKey]),
            rpcRequest(id: 2, method: "state_getStorage", params: [alphaKey])
        ]

        let responses = try await sendBatchRPC(requests: requests)

        let taoReserve = decodeU64LE(hex: responses[1] ?? nil)
        let alphaIn = decodeU64LE(hex: responses[2] ?? nil)

        return SubtensorSubnetReserves(
            netuid: netuid,
            taoReserve: taoReserve,
            alphaInReserve: alphaIn
        )
    }
}
