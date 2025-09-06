import Foundation
import SubstrateSdk

/**
 * Since Cuckoo v2 working only in sandbox we can't refer files from 3rd party as previously. To create a mock:
 *  1) Add a Test class with dummy implementation that inherits class or implements protocol to mock from the library
 *  2) Add path to the Test class to the Cuckoofile.toml
 */
class TestJSONRPCEngine: JSONRPCEngine {
    func callMethod<P: Encodable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        0
    }

    func subscribe<P: Encodable, T: Decodable>(
        _: String,
        params _: P?,
        unsubscribeMethod _: String,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    )
        throws -> UInt16 {
        0
    }

    func cancelForIdentifiers(_: [UInt16]) {}

    func addBatchCallMethod<P: Encodable>(
        _: String,
        params _: P?,
        batchId _: JSONRPCBatchId
    ) throws {}

    func submitBatch(
        for _: JSONRPCBatchId,
        options _: JSONRPCOptions,
        completion _: (([Result<JSON, Error>]) -> Void)?
    ) throws -> [UInt16] {
        []
    }

    func clearBatch(for _: JSONRPCBatchId) {}
}
