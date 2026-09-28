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

    func testClaimablePublishedFromClaimPreviews() throws {
        let previews = [
            Self.claimPreview(hotkey: firstHotkey, accrued: 97_053_363, redeemable: 95_470_988, forfeited: 1_582_363),
            Self.claimPreview(hotkey: secondHotkey, accrued: 820_106, redeemable: 5260, forfeited: 814_786)
        ]

        let context = try makeContext()

        stubClaimPreviews(context.apiFactory, previews: previews)

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
            SubtensorRootClaimable(
                previews: [
                    SubtensorRootClaimPreview(
                        hotkey: firstHotkey,
                        accrued: 97_053_363,
                        redeemable: 95_470_988,
                        forfeitedEstimate: 1_582_363
                    ),
                    SubtensorRootClaimPreview(
                        hotkey: secondHotkey,
                        accrued: 820_106,
                        redeemable: 5260,
                        forfeitedEstimate: 814_786
                    )
                ]
            )
        )
    }

    func testClaimPreviewsPinnedToFetchedBlockHash() throws {
        let context = try makeContext()

        stubClaimPreviews(context.apiFactory, previews: [])

        context.positionsService.setup()
        context.claimableService.setup()

        let claimableExpectation = expectation(description: "claimable published")

        context.claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, _ in
            claimableExpectation.fulfill()
        }

        context.positionsService.refresh()

        wait(for: [claimableExpectation], timeout: 10)

        let blockHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(context.apiFactory, times(1)).createRootClaimPreviewsWrapper(
            coldkey: equal(to: coldkey),
            blockHash: blockHashCaptor.capture()
        )

        XCTAssertEqual(blockHashCaptor.value, bestBlockHash)
    }

    func testClaimableRefreshedOnPositionsChange() throws {
        let context = try makeContext()

        stubClaimPreviews(
            context.apiFactory,
            previews: [Self.claimPreview(hotkey: firstHotkey, accrued: 1000, redeemable: 1000, forfeited: 0)]
        )

        context.positionsService.setup()
        context.claimableService.setup()

        let claimablesExpectation = expectation(description: "claimable published twice")
        claimablesExpectation.expectedFulfillmentCount = 2

        var received: [SubtensorRootClaimable?] = []

        context.claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, newState in
            received.append(newState ?? nil)
            claimablesExpectation.fulfill()

            if received.count == 1 {
                let preview = Self.claimPreview(hotkey: self.firstHotkey, accrued: 2000, redeemable: 1900, forfeited: 100)

                self.stubClaimPreviews(context.apiFactory, previews: [preview])
                self.stubPositionsFetch(context.fetchFactory, stake: 5_000_000_000)
                context.positionsService.refresh()
            }
        }

        context.positionsService.refresh()

        wait(for: [claimablesExpectation], timeout: 10)

        XCTAssertEqual(received.last??.redeemable(for: firstHotkey), BigUInt(1900))
    }

    func testFailedPreviewFetchSetsTheFailureSignalAndTheNextSuccessClearsIt() {
        let positionsService = MockSubtensorPositionsSyncServiceProtocol()
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        let state = Multistaking.SubtensorStakingState(positions: [], prices: [:])

        stub(positionsService) { stub in
            when(
                stub.add(observer: any(), sendStateOnSubscription: any(), queue: any(), closure: any())
            ).then { _, _, queue, closure in
                (queue ?? .global()).async {
                    closure(nil, state)
                }
            }
            when(stub.remove(observer: any())).thenDoNothing()
        }

        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).then {
                CompoundOperationWrapper.createWithResult(self.bestBlockHash)
            }
            when(stub.createRootClaimPreviewsWrapper(coldkey: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            }
        }

        let claimableService = SubtensorRootClaimableService(
            coldkey: coldkey,
            positionsSyncService: positionsService,
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        let signalsExpectation = expectation(description: "failure signal set then cleared")
        signalsExpectation.expectedFulfillmentCount = 2

        var signals: [Bool] = []

        claimableService.add(failureObserver: self, sendStateOnSubscription: false, queue: .main) { _, isFailed in
            signals.append(isFailed)
            signalsExpectation.fulfill()

            if isFailed {
                self.stubClaimPreviews(apiFactory, previews: [])
            }
        }

        claimableService.setup()

        wait(for: [signalsExpectation], timeout: 10)

        XCTAssertEqual(signals, [true, false])
    }

    func testRedeemableForHotkey() {
        let claimable = SubtensorRootClaimable(
            previews: [
                SubtensorRootClaimPreview(
                    hotkey: firstHotkey,
                    accrued: 820_106,
                    redeemable: 5260,
                    forfeitedEstimate: 814_786
                )
            ]
        )

        XCTAssertEqual(claimable.redeemable(for: firstHotkey), BigUInt(5260))
        XCTAssertEqual(claimable.redeemable(for: secondHotkey), 0)
    }

    func testTotalRedeemableSumsEveryColdkeyPreview() {
        let claimable = SubtensorRootClaimable(
            previews: [
                SubtensorRootClaimPreview(
                    hotkey: firstHotkey,
                    accrued: 97_053_363,
                    redeemable: 95_470_988,
                    forfeitedEstimate: 1_582_363
                ),
                SubtensorRootClaimPreview(
                    hotkey: secondHotkey,
                    accrued: 820_106,
                    redeemable: 5260,
                    forfeitedEstimate: 814_786
                )
            ]
        )

        XCTAssertEqual(claimable.totalRedeemable, BigUInt(95_476_248))
    }

    func testThrottleAfterACompletedFetchRemovesThePositionsObserver() {
        let positionsService = MockSubtensorPositionsSyncServiceProtocol()
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stubClaimPreviews(apiFactory, previews: [])

        let state = Multistaking.SubtensorStakingState(positions: [], prices: [:])

        stub(positionsService) { stub in
            when(
                stub.add(observer: any(), sendStateOnSubscription: any(), queue: any(), closure: any())
            ).then { _, _, queue, closure in
                (queue ?? .global()).async {
                    closure(nil, state)
                }
            }
            when(stub.remove(observer: any())).thenDoNothing()
        }

        let claimableService = SubtensorRootClaimableService(
            coldkey: coldkey,
            positionsSyncService: positionsService,
            operationFactory: apiFactory,
            operationQueue: OperationQueue()
        )

        let claimableExpectation = expectation(description: "claimable published")

        claimableService.add(observer: self, sendStateOnSubscription: false, queue: .main) { _, _ in
            claimableExpectation.fulfill()
        }

        claimableService.setup()

        wait(for: [claimableExpectation], timeout: 10)

        clearInvocations(positionsService)

        claimableService.throttle()

        verify(positionsService, times(1)).remove(observer: any())
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

    private func stubClaimPreviews(
        _ apiFactory: MockSubtensorApiOperationFactoryProtocol,
        previews: [SubtensorStakingPallet.BasketClaimPreview]
    ) {
        stub(apiFactory) { stub in
            when(stub.createBestBlockHashWrapper()).then {
                CompoundOperationWrapper.createWithResult(self.bestBlockHash)
            }
            when(stub.createRootClaimPreviewsWrapper(coldkey: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(previews)
            }
        }
    }

    private static func claimPreview(
        hotkey: AccountId,
        accrued: Balance,
        redeemable: Balance,
        forfeited: Balance
    ) -> SubtensorStakingPallet.BasketClaimPreview {
        SubtensorStakingPallet.BasketClaimPreview(
            hotkey: hotkey,
            owedShares: 1_000_000,
            accruedTao: accrued,
            redeemableTao: redeemable,
            forfeitedTaoEst: forfeited,
            rows: 120,
            rowsToSell: 20,
            dustRows: 100,
            swept: 0,
            flushedCredits: 3
        )
    }
}
