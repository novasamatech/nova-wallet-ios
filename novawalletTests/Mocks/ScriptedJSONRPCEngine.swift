import Foundation
@testable import novawallet
import SubstrateSdk

/// Answers JSON-RPC calls from a closure and records them. The closure returns what the node would put
/// into `result` (anything `JSONSerialization` accepts). It runs off the calling thread, the way a socket
/// delivers a response: `JSONRPCOperation` holds its lock while issuing the call, and a test may keep
/// a response back by blocking in the closure.
class ScriptedJSONRPCEngine: TestJSONRPCEngine {
    struct Call: Equatable {
        let method: String
        let params: [String]
    }

    typealias Handler = (Call) throws -> Any

    private let handler: Handler
    private let lock = NSLock()
    private var storedCalls: [Call] = []

    var calls: [Call] {
        lock.lock()

        defer {
            lock.unlock()
        }

        return storedCalls
    }

    var calledMethods: [String] { calls.map(\.method) }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    override func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let call = Call(method: method, params: try Self.describe(params))

        lock.lock()
        storedCalls.append(call)
        lock.unlock()

        DispatchQueue.global().async {
            let result: Result<T, Error> = Result {
                // wrapped into an array: a bare string is not a JSON document for JSONSerialization
                let data = try JSONSerialization.data(withJSONObject: [try self.handler(call)])

                guard let value = try JSONDecoder().decode([T].self, from: data).first else {
                    throw JSONRPCEngineError.emptyResult
                }

                return value
            }

            closure?(result)
        }

        return 1
    }

    private static func describe<P: Encodable>(_ params: P?) throws -> [String] {
        guard let params else {
            return []
        }

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(params))

        return (json as? [Any] ?? [json]).map { "\($0)" }
    }
}

/// The scripted engine as the connection `ChainRegistry` services hold for a chain
final class ScriptedChainConnection: ScriptedJSONRPCEngine, ChainConnection {
    var urls: [URL] { [] }

    var state: WebSocketEngine.State { .notConnected(url: nil) }

    func changeUrls(_: [URL]) {}

    func connect() {}

    func disconnect(_: Bool) {}
}

extension ScriptedJSONRPCEngine.Call {
    /// The runtime function and its SCALE encoded argument of a `state_call`
    var stateCall: (function: String, argument: String, blockHash: String?)? {
        guard method == StateCallRpc.method, params.count >= 2 else {
            return nil
        }

        return (params[0], params[1], params.count > 2 ? params[2] : nil)
    }
}

/// A node that serves runtime metadata the way `Metadata_metadata_versions` / `Metadata_metadata_at_version`
/// and the legacy `state_getMetadata` do, plus the runtime version and the best block hash.
struct RuntimeMetadataNodeScript {
    static let blockHash = "0x" + String(repeating: "bb", count: 32)

    /// Versions the runtime lists; nil makes the versions call fail, as on a runtime without the Metadata api
    var versions: [UInt32]?

    /// Opaque metadata by version; a listed version without bytes makes the call fail
    var metadataByVersion: [UInt32: Data] = [:]

    var legacyMetadata: Data?

    var runtimeVersion = RuntimeVersionFull(specVersion: 1, transactionVersion: 1, specName: "test")

    /// Called before a call is answered: a place to keep the response back or to count the calls
    var onCall: ((ScriptedJSONRPCEngine.Call) -> Void)?

    func makeEngine() -> ScriptedJSONRPCEngine {
        ScriptedJSONRPCEngine(handler: makeHandler())
    }

    func makeConnection() -> ScriptedChainConnection {
        ScriptedChainConnection(handler: makeHandler())
    }

    private func makeHandler() -> ScriptedJSONRPCEngine.Handler {
        { call in
            onCall?(call)

            switch call.method {
            case StateCallRpc.method:
                return try answerStateCall(call)
            case RPCMethod.getRuntimeMetadata:
                guard let legacyMetadata else {
                    throw CommonError.dataCorruption
                }

                return legacyMetadata.toHex(includePrefix: true)
            case RPCMethod.getRuntimeVersion:
                let version: [String: Any] = [
                    "specVersion": runtimeVersion.specVersion,
                    "transactionVersion": runtimeVersion.transactionVersion,
                    "specName": runtimeVersion.specName
                ]

                return version
            case RPCMethod.getBlockHash:
                return Self.blockHash
            default:
                throw CommonError.undefined
            }
        }
    }

    private func answerStateCall(_ call: ScriptedJSONRPCEngine.Call) throws -> Any {
        guard let stateCall = call.stateCall else {
            throw CommonError.dataCorruption
        }

        switch stateCall.function {
        case RuntimeFetchOperationFactory.availableVersionsCall:
            guard let versions else {
                throw CommonError.undefined
            }

            return try versions.scaleEncoded().toHex(includePrefix: true)
        case RuntimeFetchOperationFactory.metadataAtVersionCall:
            let version = try UInt32(scaleDecoder: ScaleDecoder(data: Data(hexString: stateCall.argument)))

            guard let versions, versions.contains(version) else {
                // Option<OpaqueMetadata>::None
                return "0x00"
            }

            guard let metadata = metadataByVersion[version] else {
                throw CommonError.dataCorruption
            }

            return metadata.toHex(includePrefix: true)
        default:
            throw CommonError.undefined
        }
    }
}
