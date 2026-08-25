import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorStakingPositionsSyncServiceTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)

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

    func testRefreshBeforeSetupFetchesNothing() throws {
        let (service, fetchFactory) = try makeService()

        stubFetch(fetchFactory, result: .success(Self.makeState(hotkey: hotkey, stake: 1)))

        service.refresh()

        verify(fetchFactory, never()).createStateWrapper(for: any())
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
