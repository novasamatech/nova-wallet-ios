import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import Operation_iOS
import XCTest

final class TransactionTrackingFacadeTests: XCTestCase {
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0, isEthereumBased: true)
    private let tracker = MockChainTransactionTracking()
    private let watch = MockTransactionWatching()
    private let resolver = MockTransactionHistoryResolving()
    private let eventCenter = MockEventCenterProtocol()
    private var resultClosures: [(TransactionWatchResult) -> Void] = []

    func testFreshTrackUpgradesRecoveredWatchOnce() {
        let facade = makeFacade()

        facade.track(makeRequest(nonce: nil, mode: .recovered(rowAge: 60)))
        facade.track(makeRequest(nonce: 7, mode: .fresh))
        facade.track(makeRequest(nonce: 7, mode: .fresh))

        let requests = ArgumentCaptor<TransactionTrackingRequest>()
        verify(tracker, times(2)).startWatch(for: requests.capture(), chain: any(), onResult: any())
        guard case let .evm(evidence)? = requests.value?.evidence else { return XCTFail("No watch started") }
        XCTAssertEqual(evidence.nonce, 7)
    }

    func testOutcomeIsResolvedOnceAndKeyIsNotTrackedAgain() {
        let facade = makeFacade()
        let resolved = expectation(description: "Resolution notified")
        stub(eventCenter) { stub in
            stub.notify(with: any()).then { _ in resolved.fulfill() }
        }

        facade.track(makeRequest(nonce: 7, mode: .fresh))
        resultClosures.first?(.decided(.dropped(.nonceConsumed)))
        resultClosures.first?(.decided(.dropped(.nonceConsumed)))
        wait(for: [resolved], timeout: Constants.defaultExpectationDuration)
        facade.track(makeRequest(nonce: 7, mode: .recovered(rowAge: 60)))

        verify(resolver, times(1)).createResolutionWrapper(for: any(), outcome: any())
        verify(tracker, times(1)).startWatch(for: any(), chain: any(), onResult: any())
    }

    func testBudgetEndAnswersStillPendingAndWatchStillResolves() throws {
        let facade = makeFacade()
        let request = makeRequest(nonce: 7, mode: .fresh)
        let resolved = expectation(description: "Resolution notified")
        stub(eventCenter) { stub in
            stub.notify(with: any()).then { _ in resolved.fulfill() }
        }

        facade.track(request)
        let result = try waitForResult(of: facade.createResultWrapper(for: request.key, budget: 0.05))
        verify(watch, never()).stop()
        resultClosures.first?(.decided(.dropped(.nonceConsumed)))
        wait(for: [resolved], timeout: Constants.defaultExpectationDuration)

        guard case .stillPending = result else { return XCTFail("Budget end did not answer still pending") }
        verify(resolver, times(1)).createResolutionWrapper(for: any(), outcome: any())
    }

    func testWaiterAttachedAfterResolutionGetsTheOutcome() throws {
        let facade = makeFacade()
        let request = makeRequest(nonce: 7, mode: .fresh)
        let resolved = expectation(description: "Resolution notified")
        stub(eventCenter) { stub in
            stub.notify(with: any()).then { _ in resolved.fulfill() }
        }

        facade.track(request)
        resultClosures.first?(.decided(.dropped(.nonceConsumed)))
        wait(for: [resolved], timeout: Constants.defaultExpectationDuration)
        let result = try waitForResult(of: facade.createResultWrapper(for: request.key, budget: 60))

        guard case .resolved(.dropped) = result else { return XCTFail("Late waiter did not get the outcome") }
    }
}

private extension TransactionTrackingFacadeTests {
    func makeFacade() -> TransactionTrackingFacade {
        let chainRegistry = MockChainRegistryProtocol()
        stub(chainRegistry) { [chain] stub in
            stub.getChain(for: any()).thenReturn(chain)
        }
        stub(tracker) { stub in
            stub.canTrack(chain: any()).thenReturn(true)
            stub.startWatch(for: any(), chain: any(), onResult: any()).then { _, _, onResult in
                self.resultClosures.append(onResult)
                return self.watch
            }
        }
        stub(watch) { stub in
            stub.checkNow().thenDoNothing()
            stub.stop().thenDoNothing()
        }
        stub(resolver) { stub in
            stub.createResolutionWrapper(for: any(), outcome: any()).then { _, _ in .createWithResult(()) }
        }

        return TransactionTrackingFacade(
            trackers: [tracker],
            resolver: resolver,
            pickup: MockPendingTransactionPickupProtocol(),
            chainRegistry: chainRegistry,
            applicationHandler: ApplicationHandler(),
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    func waitForResult(
        of wrapper: CompoundOperationWrapper<TransactionTrackingResult>
    ) throws -> TransactionTrackingResult {
        let completed = expectation(description: "Result delivered")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: Constants.defaultExpectationDuration)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func makeRequest(nonce: BigUInt?, mode: TransactionTrackingMode) -> TransactionTrackingRequest {
        TransactionTrackingRequest(
            key: TransactionTrackingKey(chainId: chain.chainId, transactionHash: "0xab"),
            evidence: .evm(EvmTrackingEvidence(sender: Data(repeating: 1, count: 20), nonce: nonce)),
            mode: mode
        )
    }
}
