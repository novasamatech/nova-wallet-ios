import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo
import SubstrateSdk

final class SubtensorStakingPositionsSyncServiceTests: XCTestCase {
    private typealias SyncService = SubtensorStakingPositionsSyncService
    private typealias PositionKey = SyncService.PositionKey

    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)
    let otherHotkey = Data(repeating: 3, count: 32)

    func testRefreshPublishesFetchedState() throws {
        let state = Self.makeState(hotkey: hotkey, stake: 1_000_000_000)
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(state))

        service.setup()

        let stateExpectation = expectation(description: "state published")
        var received: Multistaking.SubtensorStakingState?

        service.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received = newState ?? nil
            stateExpectation.fulfill()
        }

        service.refresh()

        wait(for: [stateExpectation], timeout: 10)

        XCTAssertEqual(received, state)
    }

    func testPublishedStateKeepsAvailabilityAndUnpricedNetuids() throws {
        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: 7,
                    stakeAlpha: 3_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [7: 0],
            availability: [
                7: SubtensorStakingPallet.StakeAvailability(
                    total: 3_000_000_000,
                    locked: 1_000_000_000,
                    available: 2_000_000_000
                )
            ],
            unpricedNetuids: [7]
        )

        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(state))

        service.setup()

        let stateExpectation = expectation(description: "state published")
        var received: Multistaking.SubtensorStakingState?

        service.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received = newState ?? nil
            stateExpectation.fulfill()
        }

        service.refresh()

        wait(for: [stateExpectation], timeout: 10)

        XCTAssertEqual(received?.availability, state.availability)
        XCTAssertEqual(received?.unpricedNetuids, [7])
    }

    func testRefreshReplacesPreviousState() throws {
        let firstState = Self.makeState(hotkey: hotkey, stake: 1_000_000_000)
        let secondState = Self.makeState(hotkey: hotkey, stake: 3_000_000_000)
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(firstState))

        service.setup()

        let statesExpectation = expectation(description: "both states published")
        statesExpectation.expectedFulfillmentCount = 2

        var received: [Multistaking.SubtensorStakingState?] = []

        service.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received.append(newState ?? nil)
            statesExpectation.fulfill()

            if received.count == 1 {
                self.stubFetch(fetchFactory, result: .success(secondState))
                service.refresh()
            }
        }

        service.refresh()

        wait(for: [statesExpectation], timeout: 10)

        XCTAssertEqual(received, [firstState, secondState])
    }

    func testFetchFailureKeepsLastState() throws {
        let state = Self.makeState(hotkey: hotkey, stake: 1_000_000_000)
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(state))

        service.setup()

        let stateExpectation = expectation(description: "state published")

        service.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, _ in
            stateExpectation.fulfill()
        }

        service.refresh()

        wait(for: [stateExpectation], timeout: 10)

        stubFetch(fetchFactory, result: .failure(CommonError.dataCorruption))

        service.refresh()

        let retainedExpectation = expectation(description: "last state retained")
        var retained: Multistaking.SubtensorStakingState?

        let lateObserver = NSObject()

        service.add(observer: lateObserver, sendStateOnSubscription: true, queue: .main) { _, newState in
            retained = newState ?? nil
            retainedExpectation.fulfill()
        }

        wait(for: [retainedExpectation], timeout: 10)

        XCTAssertEqual(retained, state)
    }

    func testFetchFailureNotifiesFailureObservers() throws {
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .failure(CommonError.dataCorruption))

        service.setup()

        let failureExpectation = expectation(description: "failure published")
        var received: Bool?

        service.add(failureObserver: self, sendStateOnSubscription: false, queue: .main) { _, isFailed in
            received = isFailed
            failureExpectation.fulfill()
        }

        service.refresh()

        wait(for: [failureExpectation], timeout: 10)

        XCTAssertEqual(received, true)
    }

    func testSuccessfulFetchClearsTheFailureFlag() throws {
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .failure(CommonError.dataCorruption))

        service.setup()

        let flagsExpectation = expectation(description: "failure raised then cleared")
        flagsExpectation.expectedFulfillmentCount = 2

        var received: [Bool] = []

        service.add(failureObserver: self, sendStateOnSubscription: false, queue: .main) { _, isFailed in
            received.append(isFailed)
            flagsExpectation.fulfill()

            if received.count == 1 {
                self.stubFetch(
                    fetchFactory,
                    result: .success(Self.makeState(hotkey: self.hotkey, stake: 1_000_000_000))
                )
                service.refresh()
            }
        }

        service.refresh()

        wait(for: [flagsExpectation], timeout: 10)

        XCTAssertEqual(received, [true, false])
    }

    func testRefreshBeforeSetupFetchesNothing() throws {
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(Self.makeState(hotkey: hotkey, stake: 1)))

        service.refresh()

        verify(fetchFactory, never()).createStateWrapper(for: any())
    }

    func testHotkeyAlphaBatchDecodesTheMappedAmount() throws {
        let batch = try makeAlphaBatch(values: [("key", .stringValue("2591407748"))])

        XCTAssertEqual(batch.amounts, ["key": 2_591_407_748])
    }

    func testHotkeyAlphaBatchReadsAnUnsetKeyAsZero() throws {
        let batch = try makeAlphaBatch(values: [("key", .null)])

        XCTAssertEqual(batch.amounts, ["key": 0])
    }

    func testHotkeyAlphaBatchSkipsValuesWithoutAMappingKey() throws {
        let batch = try makeAlphaBatch(values: [(nil, .stringValue("7"))])

        XCTAssertTrue(batch.amounts.isEmpty)
    }

    func testHotkeyAlphaMergeKeepsDenominatorsAbsentFromThePartialUpdate() throws {
        let first = PositionKey(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid)
        let second = PositionKey(hotkey: otherHotkey, netuid: 64)

        let seeded = SyncService.merging(
            [:],
            with: try makeAlphaBatch(values: [
                (SyncService.mappingKey(for: first), .stringValue("100")),
                (SyncService.mappingKey(for: second), .stringValue("200"))
            ]),
            subscribedKeys: [first, second]
        )

        let merged = SyncService.merging(
            seeded,
            with: try makeAlphaBatch(values: [
                (SyncService.mappingKey(for: second), .stringValue("300"))
            ]),
            subscribedKeys: [first, second]
        )

        XCTAssertEqual(merged, [first: 100, second: 300])
    }

    func testHotkeyAlphaMergeIgnoresPayloadKeysOutsideTheSubscribedSet() throws {
        let subscribed = PositionKey(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid)
        let stranger = PositionKey(hotkey: otherHotkey, netuid: 64)

        let merged = SyncService.merging(
            [:],
            with: try makeAlphaBatch(values: [
                (SyncService.mappingKey(for: stranger), .stringValue("500"))
            ]),
            subscribedKeys: [subscribed]
        )

        XCTAssertTrue(merged.isEmpty)
    }

    func testHotkeyAlphaPruneDropsKeysThatLeftTheSubscribedSet() {
        let kept = PositionKey(hotkey: hotkey, netuid: SubtensorStakingPallet.rootNetuid)
        let dropped = PositionKey(hotkey: otherHotkey, netuid: 64)

        let pruned = SyncService.pruning([kept: 100, dropped: 200], to: [kept])

        XCTAssertEqual(pruned, [kept: 100])
    }

    private func makeAlphaBatch(values: [(String?, JSON)]) throws -> SubtensorHotkeyAlphaBatch {
        try SubtensorHotkeyAlphaBatch(
            values: values.map {
                BatchStorageSubscriptionResultValue(mappingKey: $0.0, value: $0.1)
            },
            blockHashJson: .null,
            context: nil
        )
    }

    private static func makeState(
        hotkey: AccountId,
        stake: Balance
    ) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: stake,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: false
                )
            ],
            prices: [:]
        )
    }

    private func makeService() throws -> (
        SubtensorStakingPositionsSyncService,
        MockSubtensorStakeStateFetchFactoryProtocol
    ) {
        let fetchFactory = MockSubtensorStakeStateFetchFactoryProtocol()

        let runtimeService = RuntimeCodingServiceStub(
            factory: try RuntimeCodingServiceStub.createBittensorCodingFactory()
        )

        let service = SubtensorStakingPositionsSyncService(
            accountId: coldkey,
            stakeStateFetchFactory: fetchFactory,
            connection: TestJSONRPCEngine(),
            runtimeService: runtimeService,
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.positions.sync"),
            logger: Logger.shared
        )

        return (service, fetchFactory)
    }

    private func stubFetch(
        _ fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol,
        result: Result<Multistaking.SubtensorStakingState, Error>
    ) {
        stub(fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                switch result {
                case let .success(state):
                    return CompoundOperationWrapper.createWithResult(state)
                case let .failure(error):
                    return CompoundOperationWrapper.createWithError(error)
                }
            }
        }
    }
}
