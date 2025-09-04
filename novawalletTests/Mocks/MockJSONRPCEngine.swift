import Foundation
import SubstrateSdk

typealias CallMethodClosure = (String, Any?, JSONRPCOptions, Any?) -> UInt16

typealias SubscribeClosure = (String, Any, String, Any, (Error, Bool) -> Void) -> UInt16

class MockJSONRPCEngine {
    private var callMethodClosure: CallMethodClosure?
    private var subscribeClosure: SubscribeClosure?
    
    func stubCallMethod(
        _ closure: @escaping CallMethodClosure
    ) {
        callMethodClosure = closure
    }
    
    func stubSubscribe(
        _ closure: @escaping SubscribeClosure
    ) {
        subscribeClosure = closure
    }
}

extension MockJSONRPCEngine: JSONRPCEngine {
    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        callMethodClosure?(method, params, options, closure) ?? 0
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        unsubscribeMethod: String,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    )
    throws -> UInt16 {
        subscribeClosure?(method, params, unsubscribeMethod, updateClosure, failureClosure) ?? 0
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
