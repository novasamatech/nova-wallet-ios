@testable import novawallet
import Operation_iOS
import XCTest

/// Pins the operation semantics every factory in the app is composed from: result extraction, dependency
/// and cancellation propagation, wrapper composition helpers, the combining service and the cancellable
/// call store. Behaviour recorded on Operation-iOS 2.1.2.
final class OperationWrapperCharacterizationTests: XCTestCase {
    private let operationQueue = OperationQueue()

    // MARK: Base operations

    func testClosureOperationReturnsValueOrError() {
        let success = ClosureOperation<Int> { 5 }
        let failure = ClosureOperation<Int> { throw CommonError.dataCorruption }

        operationQueue.addOperations([success, failure], waitUntilFinished: true)

        XCTAssertEqual(try success.extractNoCancellableResultData(), 5)
        XCTAssertThrowsError(try failure.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? CommonError, .dataCorruption)
        }
    }

    func testPresetResultSkipsClosure() {
        var executed = false
        let operation = ClosureOperation<Int> {
            executed = true
            return 1
        }
        operation.result = .success(42)

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertFalse(executed)
        XCTAssertEqual(try operation.extractNoCancellableResultData(), 42)
    }

    func testConfigurationBlockRunsBeforeClosureAndOnlyOnce() {
        var events: [String] = []
        let operation = ClosureOperation<Void> { events.append("closure") }
        operation.configurationBlock = { events.append("configuration") }

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(events, ["configuration", "closure"])
        XCTAssertNil(operation.configurationBlock)
    }

    func testConfigurationBlockCanShortCircuitWithResult() {
        var executed = false
        let operation = ClosureOperation<Int> {
            executed = true
            return 1
        }
        operation.configurationBlock = { operation.result = .failure(CommonError.undefined) }

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertFalse(executed)
        XCTAssertThrowsError(try operation.extractNoCancellableResultData())
    }

    func testOperationCancelledBeforeStartIsFinishedWithoutResult() throws {
        let operation = ClosureOperation<Int> { 1 }

        operation.cancel()

        // cancel() finishes the operation at once, so it must not be enqueued afterwards
        XCTAssertTrue(operation.isCancelled)
        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.isExecuting)
        XCTAssertNil(operation.result)
        XCTAssertNil(try operation.extractResultData())
        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            guard case BaseOperationError.parentOperationCancelled = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDependentOperationSeesFailureOfCancelledDependency() {
        let dependency = ClosureOperation<Int> { 1 }
        let dependent = ClosureOperation<Int> { try dependency.extractNoCancellableResultData() + 1 }
        dependent.addDependency(dependency)
        dependency.cancel()

        operationQueue.addOperations([dependent], waitUntilFinished: true)

        XCTAssertThrowsError(try dependent.extractNoCancellableResultData()) { error in
            guard case BaseOperationError.parentOperationCancelled = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAsyncClosureOperationCompletesFromAnotherQueue() {
        let operation = AsyncClosureOperation<String> { completion in
            DispatchQueue.global().async { completion(.success("done")) }
        }

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), "done")
    }

    func testAsyncClosureOperationRunsCancellationClosureOnlyWhileExecuting() {
        var cancellations = 0
        let started = expectation(description: "operation started")
        let pending = AsyncClosureOperation<Int>(
            operationClosure: { _ in started.fulfill() },
            cancelationClosure: { cancellations += 1 }
        )
        let notStarted = AsyncClosureOperation<Int>(
            operationClosure: { _ in },
            cancelationClosure: { cancellations += 10 }
        )

        notStarted.cancel()
        operationQueue.addOperation(pending)
        wait(for: [started], timeout: 10)
        pending.cancel()
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(cancellations, 1)
        XCTAssertNil(pending.result)
        XCTAssertTrue(pending.isFinished)
    }

    func testLateCompletionAfterCancelIsIgnored() {
        var storedCompletion: ((Result<Int, Error>) -> Void)?
        let started = expectation(description: "operation started")
        let operation = AsyncClosureOperation<Int> { completion in
            storedCompletion = completion
            started.fulfill()
        }

        operationQueue.addOperation(operation)
        wait(for: [started], timeout: 10)
        operation.cancel()
        storedCompletion?(.success(1))

        XCTAssertNil(operation.result)
    }

    // MARK: Wrappers

    func testWrapperCompositionOrderAndResult() throws {
        var order: [String] = []
        let lock = NSLock()
        let record: (String) -> Void = { name in
            lock.lock()
            order.append(name)
            lock.unlock()
        }

        let first = ClosureOperation<Int> {
            record("first")
            return 2
        }
        let second = ClosureOperation<Int> {
            record("second")
            return try first.extractNoCancellableResultData() * 10
        }
        second.addDependency(first)
        let tail = ClosureOperation<String> {
            record("tail")
            return "value \(try second.extractNoCancellableResultData())"
        }
        tail.addDependency(second)

        let wrapper = CompoundOperationWrapper(targetOperation: second)
            .insertingHead(operations: [first])
            .insertingTail(operation: tail)

        XCTAssertTrue(wrapper.allOperations.elementsEqual([first, second, tail]) { $0 === $1 })
        XCTAssertTrue(wrapper.dependencies.elementsEqual([first, second]) { $0 === $1 })

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertEqual(order, ["first", "second", "tail"])
        XCTAssertEqual(try wrapper.targetOperation.extractNoCancellableResultData(), "value 20")
    }

    func testWrapperAddDependencyLinksEveryOperation() {
        let upstream = CompoundOperationWrapper(
            targetOperation: ClosureOperation<Int> { 1 },
            dependencies: [ClosureOperation<Int> { 0 }]
        )
        let downstream = CompoundOperationWrapper(
            targetOperation: ClosureOperation<Int> { 2 },
            dependencies: [ClosureOperation<Int> { 3 }]
        )

        downstream.addDependency(wrapper: upstream)

        for operation in downstream.allOperations {
            XCTAssertEqual(operation.dependencies.count, 2)
            XCTAssertTrue(operation.dependencies.allSatisfy { dependency in
                upstream.allOperations.contains { $0 === dependency }
            })
        }
    }

    func testWrapperCancelCancelsAllOperations() {
        let wrapper = CompoundOperationWrapper(
            targetOperation: ClosureOperation<Int> { 1 },
            dependencies: [ClosureOperation<Int> { 0 }]
        )

        wrapper.cancel()

        XCTAssertTrue(wrapper.allOperations.allSatisfy(\.isCancelled))
        XCTAssertTrue(wrapper.allOperations.allSatisfy(\.isFinished))
        XCTAssertNil(wrapper.targetOperation.result)
    }

    func testCreateWithResultAndError() {
        let success = CompoundOperationWrapper<Int>.createWithResult(7)
        let failure = CompoundOperationWrapper<Int>.createWithError(CommonError.undefined)

        operationQueue.addOperations(success.allOperations + failure.allOperations, waitUntilFinished: true)

        XCTAssertTrue(success.dependencies.isEmpty)
        XCTAssertEqual(try success.targetOperation.extractNoCancellableResultData(), 7)
        XCTAssertThrowsError(try failure.targetOperation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? CommonError, .undefined)
        }
    }

    // MARK: Combining service

    func testCombiningServiceCollectsResultsInWrapperOrder() throws {
        let wrapper = OperationCombiningService<Int>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            (1 ... 5).map { value in CompoundOperationWrapper(targetOperation: ClosureOperation { value * value }) }
        }
        .longrunOperation()

        operationQueue.addOperations([wrapper], waitUntilFinished: true)

        XCTAssertEqual(try wrapper.extractNoCancellableResultData(), [1, 4, 9, 16, 25])
    }

    func testCombiningServiceFailsWhenAnyWrapperFails() {
        let operation = OperationCombiningService<Int>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            [.createWithResult(1), .createWithError(CommonError.noDataRetrieved)]
        }
        .longrunOperation()

        operationQueue.addOperations([operation], waitUntilFinished: true)

        XCTAssertThrowsError(try operation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? CommonError, .noDataRetrieved)
        }
    }

    func testCompoundWrapperVariants() throws {
        let manager = OperationManager(operationQueue: operationQueue)
        let nonOptional = OperationCombiningService<Int>.compoundNonOptionalWrapper(operationManager: manager) {
            .createWithResult(3)
        }
        let missing = OperationCombiningService<Int>.compoundWrapper(operationManager: manager) { nil }
        let optional = OperationCombiningService<Int>.compoundOptionalWrapper(operationManager: manager) {
            CompoundOperationWrapper<Int?>.createWithResult(nil)
        }
        let throwing = OperationCombiningService<Int>.compoundNonOptionalWrapper(operationManager: manager) {
            throw CommonError.dataCorruption
        }

        let all = nonOptional.allOperations + missing.allOperations + optional.allOperations + throwing.allOperations
        operationQueue.addOperations(all, waitUntilFinished: true)

        XCTAssertEqual(try nonOptional.targetOperation.extractNoCancellableResultData(), 3)
        XCTAssertNil(try missing.targetOperation.extractNoCancellableResultData())
        XCTAssertNil(try optional.targetOperation.extractNoCancellableResultData())
        XCTAssertThrowsError(try throwing.targetOperation.extractNoCancellableResultData()) { error in
            XCTAssertEqual(error as? CommonError, .dataCorruption)
        }
    }

    // MARK: Execution helpers (the app's own copies: Operation-iOS exports helpers with the same names)

    func testExecuteDeliversResultOnCallbackQueue() {
        let delivered = expectation(description: "callback delivered")
        var result: Result<Int, Error>?

        novawallet.execute(
            wrapper: CompoundOperationWrapper<Int>.createWithResult(11),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { callbackResult in
            XCTAssertTrue(Thread.isMainThread)
            result = callbackResult
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 10)

        XCTAssertEqual(try result?.get(), 11)
    }

    func testCancellableCallStoreDropsCallbackOfCancelledCall() {
        let callStore = novawallet.CancellableCallStore()
        let started = expectation(description: "stale call started")
        let delivered = expectation(description: "fresh call delivered")
        var results: [Int] = []

        let stale = CompoundOperationWrapper(targetOperation: AsyncClosureOperation<Int> { _ in started.fulfill() })
        novawallet.executeCancellable(
            wrapper: stale,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { _ in
            results.append(-1)
        }
        wait(for: [started], timeout: 10)
        XCTAssertTrue(callStore.hasCall)

        callStore.cancel()
        XCTAssertFalse(callStore.hasCall)

        novawallet.executeCancellable(
            wrapper: CompoundOperationWrapper<Int>.createWithResult(2),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { result in
            results.append((try? result.get()) ?? 0)
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 10)

        XCTAssertEqual(results, [2])
        XCTAssertFalse(callStore.hasCall)
    }
}
