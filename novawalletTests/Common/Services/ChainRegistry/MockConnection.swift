import Foundation
@testable import novawallet
import SubstrateSdk

final class MockConnection {
    let internalConnection = MockJSONRPCEngine()
    let autobalancing = MockConnectionAutobalancing()
    let stateReporting = MockConnectionStateReporting()
}

extension MockConnection: ChainConnection {
    var urls: [URL] { autobalancing.urls }

    func changeUrls(_ newUrls: [URL]) {
        autobalancing.changeUrls(newUrls)
    }

    var state: WebSocketEngine.State {
        stateReporting.state
    }

    func connect() {}

    func disconnect(_ force: Bool) {}

    func subscribe<P, T>(
        _ method: String, params: P?,
        unsubscribeMethod: String,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 where P : Encodable, T : Decodable {
        try internalConnection.subscribe(
            method,
            params: params,
            unsubscribeMethod: unsubscribeMethod,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func callMethod<P, T>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 where P : Encodable, T : Decodable {
        try internalConnection.callMethod(
            method,
            params: params,
            options: options,
            completion: closure
        )
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        internalConnection.cancelForIdentifier(identifier)
    }

    func submitBatch(
        for batchId: JSONRPCBatchId,
        options: JSONRPCOptions,
        completion closure: (([Result<JSON, Error>]) -> Void)?
    ) throws -> UInt16 {
        try internalConnection.submitBatch(
            for: batchId,
            options: options,
            completion: closure
        )
    }

    func addBatchCallMethod<P>(
        _ method: String,
        params: P?,
        batchId: JSONRPCBatchId
    ) throws where P : Encodable {
        try internalConnection.addBatchCallMethod(
            method,
            params: params,
            batchId: batchId
        )
    }

    func clearBatch(for batchId: JSONRPCBatchId) {
        internalConnection.clearBatch(for: batchId)
    }
}
