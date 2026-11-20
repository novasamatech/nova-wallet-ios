@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

/// Pins the JSON-RPC surface of SubstrateSdk the app relies on: error and subscription update decoding from
/// literal node responses, and how `JSONRPCOperation` drives a `JSONRPCEngine`.
/// Behaviour recorded on substrate-sdk-ios 4.5.2.
final class JSONRPCCharacterizationTests: XCTestCase {
    private let operationQueue = OperationQueue()

    // MARK: Decoding

    func testErrorDecodesWithStringData() throws {
        let error = try decode(
            JSONRPCError.self,
            #"{"code":1010,"message":"Invalid Transaction","data":"Transaction is outdated"}"#
        )

        XCTAssertEqual(error.code, 1010)
        XCTAssertEqual(error.message, "Invalid Transaction")
        XCTAssertEqual(error.data, "Transaction is outdated")
    }

    func testErrorDecodesWithoutData() throws {
        let error = try decode(JSONRPCError.self, #"{"code":-32601,"message":"Method not found"}"#)

        XCTAssertEqual(error.code, -32601)
        XCTAssertEqual(error.message, "Method not found")
        XCTAssertNil(error.data)
    }

    func testErrorDropsNonStringData() throws {
        let error = try decode(
            JSONRPCError.self,
            #"{"code":-32000,"message":"Client error","data":{"reason":"bad origin"}}"#
        )

        XCTAssertEqual(error.code, -32000)
        XCTAssertNil(error.data)
    }

    func testErrorRequiresCodeAndMessage() {
        XCTAssertThrowsError(try decode(JSONRPCError.self, #"{"message":"No code"}"#))
        XCTAssertThrowsError(try decode(JSONRPCError.self, #"{"code":1}"#))
    }

    func testSubscriptionUpdateDecodesStringSubscriptionId() throws {
        let update = try decode(
            JSONRPCSubscriptionUpdate<String>.self,
            #"{"jsonrpc":"2.0","method":"state_storage","params":{"subscription":"ZmE3Yw","result":"0x01"}}"#
        )

        XCTAssertEqual(update.jsonrpc, "2.0")
        XCTAssertEqual(update.method, "state_storage")
        XCTAssertEqual(update.params.subscription, "ZmE3Yw")
        XCTAssertEqual(update.params.result, "0x01")
    }

    func testSubscriptionUpdateDecodesNumericSubscriptionId() throws {
        let update = try decode(
            JSONRPCSubscriptionUpdate<[String]>.self,
            #"{"jsonrpc":"2.0","method":"chain_newHead","params":{"subscription":4821,"result":["a","b"]}}"#
        )

        XCTAssertEqual(update.params.subscription, "4821")
        XCTAssertEqual(update.params.result, ["a", "b"])
    }

    func testSubscriptionUpdateRejectsMissingSubscriptionId() {
        XCTAssertThrowsError(
            try decode(
                JSONRPCSubscriptionUpdate<String>.self,
                #"{"jsonrpc":"2.0","method":"state_storage","params":{"result":"0x01"}}"#
            )
        )
    }

    func testSubscriptionHandlesUpdateData() throws {
        var received: [String] = []
        let subscription = JSONRPCSubscription<JSONRPCSubscriptionUpdate<String>>(
            requestId: 9,
            requestData: Data(),
            requestOptions: JSONRPCOptions(resendOnReconnect: true),
            unsubscribeMethod: RPCMethod.storageUnsubscribe,
            updateClosure: { received.append($0.params.result) },
            failureClosure: { _, _ in }
        )

        try subscription.handle(
            data: Data(#"{"jsonrpc":"2.0","method":"m","params":{"subscription":1,"result":"0x02"}}"#.utf8)
        )

        XCTAssertEqual(received, ["0x02"])
        XCTAssertEqual(subscription.requestId, 9)
        XCTAssertNil(subscription.remoteId)
        XCTAssertThrowsError(try subscription.handle(data: Data("{}".utf8)))
    }

    // MARK: JSONRPCOperation

    func testOperationSendsMethodAndParametersAndReturnsResult() throws {
        let engine = RecordingEngine(response: .success("0xabc"))
        let operation = JSONRPCListOperation<String>(engine: engine, method: "chain_getBlockHash", parameters: ["1"])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), "0xabc")
        XCTAssertEqual(engine.calls.map(\.method), ["chain_getBlockHash"])
        XCTAssertEqual(engine.calls.first?.params, #"["1"]"#)
        XCTAssertEqual(engine.calls.first?.resendOnReconnect, true)
    }

    func testOperationUsesParametersSetInConfigurationBlock() throws {
        let engine = RecordingEngine(response: .success("ok"))
        let operation = JSONRPCListOperation<String>(engine: engine, method: "system_accountNextIndex")
        operation.configurationBlock = {
            operation.parameters = ["address"]
        }

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(engine.calls.first?.params, #"["address"]"#)
    }

    func testOperationPropagatesEngineError() {
        let rpcError = JSONRPCError(message: "Invalid Transaction", code: 1010, data: nil)
        let engine = RecordingEngine(response: .failure(rpcError))
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic")

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual((error as? JSONRPCError)?.code, 1010)
        }
    }

    func testOperationFailsWhenEngineThrowsOnCall() {
        let engine = RecordingEngine(response: .success("unused"), callError: JSONRPCEngineError.unknownError)
        let operation = JSONRPCListOperation<String>(engine: engine, method: "chain_getHeader")

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? JSONRPCEngineError, .unknownError)
        }
    }

    func testOperationTimesOutAndCancelsRequest() {
        let engine = RecordingEngine(response: nil)
        let operation = JSONRPCListOperation<String>(engine: engine, method: "chain_getHeader", timeout: 1)

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? JSONRPCOperationError, .timeout)
        }
        XCTAssertEqual(engine.cancelledIdentifiers, [RecordingEngine.requestId])
    }

    func testCancellingPendingOperationCancelsEngineRequest() {
        let engine = RecordingEngine(response: nil)
        let operation = JSONRPCListOperation<String>(engine: engine, method: "chain_getHeader", timeout: 60)
        let started = expectation(description: "request issued")
        engine.onCall = { started.fulfill() }

        operationQueue.addOperation(operation)
        wait(for: [started], timeout: 10)
        operation.cancel()
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertTrue(operation.isCancelled)
        XCTAssertEqual(engine.cancelledIdentifiers, [RecordingEngine.requestId])
        XCTAssertThrowsError(try operation.extractNoCancellableResultData())
    }

    func testDefaultOptionsResendOnReconnect() {
        XCTAssertTrue(JSONRPCOptions().resendOnReconnect)
        XCTAssertFalse(JSONRPCOptions(resendOnReconnect: false).resendOnReconnect)
    }
}

private extension JSONRPCCharacterizationTests {
    func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

/// Answers every call with a preset response off the calling thread, the way a socket would.
private final class RecordingEngine: TestJSONRPCEngine {
    struct Call {
        let method: String
        let params: String?
        let resendOnReconnect: Bool
    }

    static let requestId: UInt16 = 17

    private let lock = NSLock()
    private let response: Result<String, Error>?
    private let callError: Error?

    private var storedCalls: [Call] = []
    private var storedCancelled: [UInt16] = []

    var onCall: (() -> Void)?

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return storedCalls
    }

    var cancelledIdentifiers: [UInt16] {
        lock.lock()
        defer { lock.unlock() }
        return storedCancelled
    }

    init(response: Result<String, Error>?, callError: Error? = nil) {
        self.response = response
        self.callError = callError
    }

    override func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        if let callError {
            throw callError
        }

        let encodedParams = try params.map { String(data: try JSONEncoder().encode($0), encoding: .utf8) ?? "" }

        lock.lock()
        storedCalls.append(Call(method: method, params: encodedParams, resendOnReconnect: options.resendOnReconnect))
        lock.unlock()

        onCall?()

        if let response {
            let typedResponse: Result<T, Error>

            switch response {
            case let .success(value):
                if let typedValue = value as? T {
                    typedResponse = .success(typedValue)
                } else {
                    typedResponse = .failure(JSONRPCEngineError.emptyResult)
                }
            case let .failure(error):
                typedResponse = .failure(error)
            }

            DispatchQueue.global().async {
                closure?(typedResponse)
            }
        }

        return Self.requestId
    }

    override func cancelForIdentifiers(_ identifiers: [UInt16]) {
        lock.lock()
        storedCancelled.append(contentsOf: identifiers)
        lock.unlock()
    }
}
