import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorRootClaimFlowTests: SubtensorFlowTestCase {
    private let claimFee: Balance = 8_251_374

    func testRootRewardClaimReachesConfirmFromTheClaimPreview() throws {
        let world = try SubtensorFlowWorld()
        let coldkey = SubtensorFlowChainWorld.coldkey
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)
        let networkInfoFactory = stubNetworkInfo()
        let preflightFactory = try stubPreflight(hotkeyOf: .aster, netuid: SubtensorStakingPallet.rootNetuid)

        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        world.stubRootHolds([aster: SubtensorRootHold(interval: 0, lastStakeBlock: 9_139_000)])

        world.sharedState.setup(for: coldkey)

        let claimableBeforePositions = try currentClaimable(in: world)

        verify(world.apiOperationFactory, never()).createBestBlockHashWrapper()

        feed.publish(try SubtensorFlowActiveStake.rootOnlyState())

        let root = try XCTUnwrap(SubtensorPortfolioBuilder.build(state: try awaitPositions(in: world)).root)
        let claimable = try awaitClaimable(in: world)
        let networkInfo = try run(networkInfoFactory.createNetworkInfoWrapper())
        let rewardsState = claimable.claimState(threshold: networkInfo.rootClaimableThreshold)
        let operationService = try world.createStakingOperationService(networkFee: claimFee)

        let claimFees = try rewardsState.eligibleHotkeys.map { hotkey in
            try run(operationService.createFeeWrapper(for: .claimRoot(hotkey: hotkey)))
        }

        let preflight = try run(preflightFactory.createPreflightWrapper(
            for: coldkey,
            hotkey: root.primaryHotkey,
            netuid: SubtensorStakingPallet.rootNetuid
        ))

        let confirmState = claimable.claimState(threshold: preflight.rootClaimableThreshold)
        let confirmFee = confirmState.totalFee(from: try XCTUnwrap(claimFees.first))

        let holds = try run(world.earnServices.rootHoldFactory.createHoldsWrapper(
            coldkey: coldkey,
            hotkeys: [root.primaryHotkey]
        ))

        world.sharedState.throttle()

        XCTAssertNil(claimableBeforePositions)
        XCTAssertEqual(root.primaryHotkey, aster)
        XCTAssertEqual(claimable, try SubtensorFlowActiveStake.expectedClaimable())
        XCTAssertEqual(claimable.previews.reduce(Balance.zero) { $0 + $1.redeemable }, 420_300_000)
        XCTAssertEqual(rewardsState.eligibleHotkeys, [aster])
        XCTAssertEqual(rewardsState.pendingTotal, 300_000)
        XCTAssertEqual(claimFees.map(\.amount), [claimFee])

        XCTAssertEqual(confirmState.eligibleHotkeys, [aster])
        XCTAssertEqual(confirmState.eligibleTotal, 420_000_000)
        XCTAssertEqual(confirmState.pendingTotal, 300_000)
        XCTAssertEqual(confirmFee.amount, claimFee)
        XCTAssertFalse(preflight.hasColdkeySwapAnnouncement)
        XCTAssertFalse(preflight.isSafeModeActive)
        XCTAssertEqual(holds[aster]?.isUnlocked(at: BittensorApiFixtureWorld.headBlock), true)

        verify(world.apiOperationFactory).createBestBlockHashWrapper()
        verify(world.apiOperationFactory).createRootClaimPreviewsWrapper(
            coldkey: equal(to: coldkey),
            blockHash: BittensorApiFixtureWorld.blockHash
        )

        XCTAssertEqual(SubtensorFlowURLProtocol.recordedRequests, [])
        XCTAssertEqual(world.attestation.signatures, [])
    }
}

private extension SubtensorRootClaimFlowTests {
    func currentClaimable(in world: SubtensorFlowWorld) throws -> SubtensorRootClaimable? {
        let service = try XCTUnwrap(world.sharedState.rootClaimableService)
        let delivered = expectation(description: "Claimable state delivered")
        let observer = NSObject()
        var received: SubtensorRootClaimable??

        service.add(
            observer: observer,
            sendStateOnSubscription: true,
            queue: DispatchQueue(label: "flow.claimable.current")
        ) { _, claimable in
            guard received == nil else {
                return
            }

            received = .some(claimable)
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 10)
        service.remove(observer: observer)

        return try XCTUnwrap(received)
    }

    func stubNetworkInfo() -> MockSubtensorNetworkInfoFactoryProtocol {
        let networkInfo = SubtensorNetworkInfo(
            minStake: 2_000_000,
            effectiveNominatorMinStake: 20_000_000,
            rootUnlockInterval: 0,
            rootClaimableThreshold: SubtensorStakingPallet.defaultRootClaimableThreshold,
            isSafeModeActive: false
        )

        let factory = MockSubtensorNetworkInfoFactoryProtocol()

        stub(factory) { stub in
            when(stub.createNetworkInfoWrapper()).then {
                CompoundOperationWrapper.createWithResult(networkInfo)
            }
        }

        return factory
    }
}
