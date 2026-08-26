import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorRootClaimableServiceTests: XCTestCase {
    let coldkey = Data(repeating: 1, count: 32)
    let firstHotkey = Data(repeating: 2, count: 32)
    let secondHotkey = Data(repeating: 3, count: 32)
    let bestBlockHash = "0x1122334455667788112233445566778811223344556677881122334455667788"

    func testClaimablePublishedFromPositionsState() throws {
        let positions = [
            SubtensorStakingPallet.RootBasketPosition(
                hotkey: firstHotkey,
                owedShares: 100,
                payout: BigUInt(128_709_394)
            ),
            SubtensorStakingPallet.RootBasketPosition(
                hotkey: secondHotkey,
                owedShares: 5,
                payout: BigUInt(6168)
            )
        ]

        let context = try makeContext()

        stubBasketCalls(context.apiFactory, owed: BigUInt(128_715_562), positions: positions)

        context.positionsService.setup()
        context.claimableService.setup()

        let claimableExpectation = expectation(description: "claimable published")
        var received: SubtensorRootClaimable?

        context.claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received = newState ?? nil
            claimableExpectation.fulfill()
        }

        context.positionsService.refresh()

        wait(for: [claimableExpectation], timeout: 10)

        XCTAssertEqual(
            received,
            SubtensorRootClaimable(owed: BigUInt(128_715_562), positions: positions)
        )
    }

    func testBasketCallsPinnedToFetchedBlockHash() throws {
        let context = try makeContext()

        stubBasketCalls(context.apiFactory, owed: 0, positions: [])

        context.positionsService.setup()
        context.claimableService.setup()

        let claimableExpectation = expectation(description: "claimable published")

        context.claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, _ in
            claimableExpectation.fulfill()
        }

        context.positionsService.refresh()

        wait(for: [claimableExpectation], timeout: 10)

        let owedHashCaptor = ArgumentCaptor<BlockHash?>()
        let positionsHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(context.apiFactory, times(1)).createRootBasketOwedWrapper(
            for: any(),
            blockHash: owedHashCaptor.capture()
        )
        verify(context.apiFactory, times(1)).createRootBasketPositionsWrapper(
            for: any(),
            blockHash: positionsHashCaptor.capture()
        )

        XCTAssertEqual(owedHashCaptor.value, bestBlockHash)
        XCTAssertEqual(positionsHashCaptor.value, bestBlockHash)
    }

    func testClaimableRefreshedOnPositionsChange() throws {
        let context = try makeContext()

        stubBasketCalls(context.apiFactory, owed: BigUInt(1000), positions: [])

        context.positionsService.setup()
        context.claimableService.setup()

        let claimablesExpectation = expectation(description: "claimable published twice")
        claimablesExpectation.expectedFulfillmentCount = 2

        var received: [SubtensorRootClaimable?] = []

        context.claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received.append(newState ?? nil)
            claimablesExpectation.fulfill()

            if received.count == 1 {
                self.stubBasketCalls(context.apiFactory, owed: BigUInt(2000), positions: [])
                self.stubPositionsFetch(context.fetchFactory, stake: 5_000_000_000)
                context.positionsService.refresh()
            }
        }

        context.positionsService.refresh()

        wait(for: [claimablesExpectation], timeout: 10)

        XCTAssertEqual(received.last??.owed, BigUInt(2000))
    }

    func testPayoutForHotkey() {
        let claimable = SubtensorRootClaimable(
            owed: BigUInt(1500),
            positions: [
                SubtensorStakingPallet.RootBasketPosition(
                    hotkey: firstHotkey,
                    owedShares: 10,
                    payout: BigUInt(1500)
                )
            ]
        )

        XCTAssertEqual(claimable.payout(for: firstHotkey), BigUInt(1500))
        XCTAssertEqual(claimable.payout(for: secondHotkey), 0)
    }

    private struct Context {
        let positionsService: SubtensorStakingPositionsSyncService
        let claimableService: SubtensorRootClaimableService
        let apiFactory: MockSubtensorApiOperationFactoryProtocol
        let fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol
    }

    private func makeContext() throws -> Context {
        let fetchFactory = MockSubtensorStakeStateFetchFactoryProtocol()

        stubPositionsFetch(fetchFactory, stake: 1_000_000_000)

        let runtimeService = RuntimeCodingServiceStub(
            factory: try RuntimeCodingServiceStub.createBittensorCodingFactory()
        )

        let positionsService = SubtensorStakingPositionsSyncService(
            accountId: coldkey,
            stakeStateFetchFactory: fetchFactory,
            connection: TestJSONRPCEngine(),
            runtimeService: runtimeService,
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.claimable.positions"),
            logger: Logger.shared
        )

        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        let claimableService = SubtensorRootClaimableService(
            coldkey: coldkey,
            positionsSyncService: positionsService,
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        return Context(
            positionsService: positionsService,
            claimableService: claimableService,
            apiFactory: apiFactory,
            fetchFactory: fetchFactory
        )
    }

    private func stubPositionsFetch(
        _ fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol,
        stake: Balance
    ) {
        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: firstHotkey,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: stake,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: false
                )
            ],
            prices: [:]
        )

        stub(fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(state)
            }
        }
    }

    private func stubBasketCalls(
        _ apiFactory: MockSubtensorApiOperationFactoryProtocol,
        owed: Balance,
        positions: [SubtensorStakingPallet.RootBasketPosition]
    ) {
        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).then {
                CompoundOperationWrapper.createWithResult(self.bestBlockHash)
            }
            when(stub.createRootBasketOwedWrapper(for: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(owed)
            }
            when(stub.createRootBasketPositionsWrapper(for: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(positions)
            }
        }
    }
}
