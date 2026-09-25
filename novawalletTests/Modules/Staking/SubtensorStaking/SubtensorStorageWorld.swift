import Cuckoo
import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class SubtensorStorageWorld {
    let blockHash = Data(repeating: 0xAB, count: 32)

    private let keyFactory = StorageKeyFactory()
    private let mutex = NSLock()
    private var values: [Data: Data] = [:]
    private var queries: [StorageQuery] = []

    var recordedQueries: [StorageQuery] {
        mutex.lock()
        defer { mutex.unlock() }
        return queries
    }

    static func netuidKey(_ netuid: UInt16) -> Data {
        Data([UInt8(netuid & 0xFF), UInt8(netuid >> 8)])
    }

    func prefix(of path: StorageCodingPath) throws -> Data {
        try keyFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)
    }

    func key(_ path: StorageCodingPath, _ param: Data, _ hasher: StorageHasher) throws -> Data {
        try keyFactory.createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName,
            key: param,
            hasher: hasher
        )
    }

    func key(
        _ path: StorageCodingPath,
        _ param1: Data,
        _ hasher1: StorageHasher,
        _ param2: Data,
        _ hasher2: StorageHasher
    ) throws -> Data {
        try keyFactory.createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName,
            key1: param1,
            hasher1: hasher1,
            key2: param2,
            hasher2: hasher2
        )
    }

    func set(_ hexValue: String, at key: Data) throws {
        let value = try Data(hexString: hexValue)

        mutex.lock()
        values[key] = value
        mutex.unlock()
    }

    func requestedKeyCounts(for path: StorageCodingPath) throws -> [Int] {
        let prefix = try prefix(of: path)

        return recordedQueries.compactMap { query in
            let count = query.keys.filter { $0.starts(with: prefix) }.count
            return count > 0 ? count : nil
        }
    }

    func requestedKeys() -> Set<Data> {
        Set(recordedQueries.flatMap(\.keys))
    }

    func makeEngine(failingStorage: Bool = false) -> MockTestJSONRPCEngine {
        let engine = MockTestJSONRPCEngine()
        let blockHashHex = blockHash.toHex(includePrefix: true)

        stub(engine) { stub in
            when(
                stub.callMethod(any(), params: any(StorageQuery.self), options: any(), completion: any())
            ).then { (
                _: String,
                params: StorageQuery?,
                _: JSONRPCOptions,
                completion: ((Result<[StorageUpdate], Error>) -> Void)?
            ) in
                let result: Result<[StorageUpdate], Error> = failingStorage
                    ? .failure(CommonError.dataCorruption)
                    : .success([self.respond(to: params)])

                DispatchQueue.global().async {
                    completion?(result)
                }

                return 0
            }

            when(
                stub.callMethod(any(), params: any([String].self), options: any(), completion: any())
            ).then { (_: String, _: [String]?, _: JSONRPCOptions, completion: ((Result<String, Error>) -> Void)?) in
                DispatchQueue.global().async {
                    completion?(.success(blockHashHex))
                }

                return 0
            }

            when(stub.cancelForIdentifiers(any())).thenDoNothing()
        }

        return engine
    }

    func makeConnectionStore(engine: JSONRPCEngine) throws -> RuntimeConnectionStoring {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let runtimeProvider = MockRuntimeProviderProtocol()

        stub(runtimeProvider) { stub in
            stub.fetchCoderFactoryOperation().then {
                BaseOperation.createWithResult(codingFactory)
            }
        }

        return StaticRuntimeConnectionStore(connection: engine, runtimeProvider: runtimeProvider)
    }

    private func respond(to query: StorageQuery?) -> StorageUpdate {
        mutex.lock()
        defer { mutex.unlock() }

        guard let query else {
            return StorageUpdate(blockHash: nil, changes: [])
        }

        queries.append(query)

        let changes = query.keys.map { key in
            [key.toHex(includePrefix: true), values[key]?.toHex(includePrefix: true)]
        }

        return StorageUpdate(blockHash: query.blockHash?.toHex(includePrefix: true), changes: changes)
    }
}
