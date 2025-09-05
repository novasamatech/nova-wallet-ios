import Foundation
import SubstrateSdk

/**
 * Since Cuckoo v2 working only in sandbox we can't refer files from 3rd party as previously. To create a mock:
 *  1) Add a Test class with dummy implementation that inherits class or implements protocol to mock from the library
 *  2) Add path to the Test class to the Cuckoofile.toml
 */
class TestJSONRPCEngine: JSONRPCEngine {
    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        0
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        unsubscribeMethod: String,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    )
    throws -> UInt16 {
        0
    }

    func cancelForIdentifiers(_ identifiers: [UInt16]) {}

    func addBatchCallMethod<P: Encodable>(
        _ method: String,
        params: P?,
        batchId: JSONRPCBatchId
    ) throws {}

    func submitBatch(
        for batchId: JSONRPCBatchId,
        options: JSONRPCOptions,
        completion closure: (([Result<JSON, Error>]) -> Void)?
    ) throws -> [UInt16] {
        []
    }

    func clearBatch(for batchId: JSONRPCBatchId) {}
}
