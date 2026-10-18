import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class SubtensorStakingPositionsSyncServiceTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let hotkey = Data(repeating: 2, count: 32)

    func testRefreshPublishesFetchedPositions() throws {
        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: 7,
                    stakeAlpha: 3_000_000_000,
                    isRegistered: true
                )
            ],
            availability: [
                7: SubtensorStakingPallet.StakeAvailability(available: 2_000_000_000)
            ]
        )
        let (service, fetchFactory) = try createService()
        stubFetch(fetchFactory, result: .success(state))
        service.setup()

        let received = performRefresh(on: service)

        XCTAssertEqual(received, state)
    }

    func testFetchFailureKeepsLastStateAndRaisesFailure() throws {
        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: hotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: 1_000_000_000,
                    isRegistered: false
                )
            ]
        )
        let (service, fetchFactory) = try createService()
        stubFetch(fetchFactory, result: .success(state))
        service.setup()
        _ = performRefresh(on: service)

        stubFetch(fetchFactory, result: .failure(CommonError.dataCorruption))

        let isFailed = performFailingRefresh(on: service)

        XCTAssertEqual(isFailed, true)
        XCTAssertEqual(fetchCurrentState(of: service), state)
    }

    private func performRefresh(
        on service: SubtensorStakingPositionsSyncService
    ) -> Multistaking.SubtensorStakingState? {
        let stateExpectation = expectation(description: "state published")
        var received: Multistaking.SubtensorStakingState?
        var isInitialStateSkipped = false
        let observer = NSObject()

        service.add(observer: observer, onState: { newState in
            guard isInitialStateSkipped else {
                isInitialStateSkipped = true
                return
            }

            received = newState
            stateExpectation.fulfill()
        }, onFailure: { _ in })
        service.refresh()
        wait(for: [stateExpectation], timeout: 10)
        service.remove(observer: observer)

        return received
    }

    private func performFailingRefresh(on service: SubtensorStakingPositionsSyncService) -> Bool? {
        let failureExpectation = expectation(description: "failure published")
        var isFailed: Bool?
        var isInitialFailureSkipped = false
        let observer = NSObject()

        service.add(observer: observer, onState: { _ in }, onFailure: { newValue in
            guard isInitialFailureSkipped else {
                isInitialFailureSkipped = true
                return
            }

            isFailed = newValue
            failureExpectation.fulfill()
        })
        service.refresh()
        wait(for: [failureExpectation], timeout: 10)
        service.remove(observer: observer)

        return isFailed
    }

    private func fetchCurrentState(
        of service: SubtensorStakingPositionsSyncService
    ) -> Multistaking.SubtensorStakingState? {
        let stateExpectation = expectation(description: "current state")
        var received: Multistaking.SubtensorStakingState?
        let observer = NSObject()

        service.add(observer: observer, onState: { newState in
            received = newState
            stateExpectation.fulfill()
        }, onFailure: { _ in })
        wait(for: [stateExpectation], timeout: 10)
        service.remove(observer: observer)

        return received
    }

    private func createService() throws -> (
        SubtensorStakingPositionsSyncService,
        MockSubtensorStakeStateFetchOperationFactoryProtocol
    ) {
        let fetchFactory = MockSubtensorStakeStateFetchOperationFactoryProtocol()
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let runtimeProvider = MockRuntimeProviderProtocol()

        stub(runtimeProvider) { stub in
            when(stub.fetchCoderFactoryOperation()).then { BaseOperation.createWithResult(codingFactory) }
        }

        let source = SubtensorStakeStateSource(
            accountId: coldkey,
            chainAssetId: ChainAssetId(chainId: "subtensor", assetId: 0),
            stakeStateFetchOperationFactory: fetchFactory,
            runtimeConnectionStore: StaticRuntimeConnectionStore(
                connection: TestJSONRPCEngine(),
                runtimeProvider: runtimeProvider
            ),
            eventCenter: EventCenter.shared,
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.stake.state"),
            logger: Logger.shared
        )

        let service = SubtensorStakingPositionsSyncService(
            stakeStateSource: source,
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.positions.sync"),
            logger: Logger.shared
        )

        return (service, fetchFactory)
    }

    private func stubFetch(
        _ fetchFactory: MockSubtensorStakeStateFetchOperationFactoryProtocol,
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
