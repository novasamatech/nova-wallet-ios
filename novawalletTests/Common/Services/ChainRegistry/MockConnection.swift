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

    func callMethod<P, T>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 where P : Encodable, T : Decodable {
        try internalConnection.callMethod(
            method,
            params: params,
            options: options,
            completion: closure
        )
    }

    func subscribe<P, T>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 where P : Encodable, T : Decodable {
        try internalConnection.subscribe(
            method,
            params: params,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        internalConnection.cancelForIdentifier(identifier)
    }
}
