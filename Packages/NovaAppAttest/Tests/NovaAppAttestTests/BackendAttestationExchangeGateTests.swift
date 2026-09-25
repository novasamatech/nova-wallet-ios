import XCTest
@testable import NovaAppAttest
import Operation_iOS

final class BackendAttestationExchangeGateTests: XCTestCase {
    func testExchangeCancelledWhileWaitingNeverRunsAndTheNextOneRunsAfterTheHolder() {
        let gate = BackendAttestationExchangeGate(operationQueue: OperationQueue())
        let events = BackendAttestationExchangeLog()
        let holderStarted = expectation(description: "Holder exchange started")
        var releaseHolder: (() -> Void)?

        let holderWrapper = gate.createExclusiveWrapper {
            CompoundOperationWrapper(targetOperation: AsyncClosureOperation<Void> { completion in
                events.append("holder")
                releaseHolder = { completion(.success(())) }
                holderStarted.fulfill()
            })
        }

        let cancelledWrapper = gate.createExclusiveWrapper {
            events.append("cancelled")

            return CompoundOperationWrapper.createWithResult(())
        }

        let nextWrapper = gate.createExclusiveWrapper {
            events.append("next")

            return CompoundOperationWrapper.createWithResult(())
        }

        let holderCompleted = expectation(description: "Holder exchange finished")
        holderWrapper.targetOperation.completionBlock = { holderCompleted.fulfill() }

        let nextCompleted = expectation(description: "Next exchange finished")
        nextWrapper.targetOperation.completionBlock = { nextCompleted.fulfill() }

        let operationQueue = OperationQueue()

        operationQueue.addOperations(holderWrapper.allOperations, waitUntilFinished: false)
        wait(for: [holderStarted], timeout: 10)

        cancelledWrapper.targetOperation.start()
        operationQueue.addOperations(nextWrapper.allOperations, waitUntilFinished: false)
        cancelledWrapper.cancel()

        releaseHolder?()

        wait(for: [holderCompleted, nextCompleted], timeout: 10)

        XCTAssertNoThrow(try holderWrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertNoThrow(try nextWrapper.targetOperation.extractNoCancellableResultData())
        XCTAssertEqual(events.values, ["holder", "next"])
    }
}

private final class BackendAttestationExchangeLog {
    private let mutex = NSLock()
    private var recorded: [String] = []

    var values: [String] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return recorded
    }

    func append(_ value: String) {
        mutex.lock()
        recorded.append(value)
        mutex.unlock()
    }
}
