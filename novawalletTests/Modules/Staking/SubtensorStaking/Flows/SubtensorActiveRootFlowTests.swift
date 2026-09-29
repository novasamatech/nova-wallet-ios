import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorActiveRootFlowTests: SubtensorFlowTestCase {
    private let unstakeAmount: Balance = 10_000_000_000

    func testEarnTabRootPositionAddsStakeAndUnstakesThroughTheResultWithBareRootCallsAndNoNovaFee() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let directoryService = services.validatorDirectoryService
        let coldkey = SubtensorFlowChainWorld.coldkey
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)
        let preflightFactory = try stubPreflight(hotkeyOf: .aster, netuid: SubtensorStakingPallet.rootNetuid)

        world.stubSubnets(try SubtensorFlowActiveStake.subnetsInfo())
        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        world.stubRootHolds([aster: SubtensorRootHold(interval: 0, lastStakeBlock: 9_139_000)])
        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveFixture(.subnets)
        SubtensorFlowURLProtocol.serveFixture(.validators(netuid: 0))
        SubtensorFlowURLProtocol.serveFixture(.rootYield(page: 1, pageSize: 100))
        try SubtensorFlowActiveStake.serveCharts()

        world.sharedState.setup(for: SubtensorFlowChainWorld.coldkeyAccount())
        feed.publish(try SubtensorFlowActiveStake.state())

        let yourBittensor = try openYourBittensor(in: world)

        let root = try XCTUnwrap(yourBittensor.portfolio.root)
        let actedOn = try XCTUnwrap(root.positions.first)
        let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)
        let claimable = try awaitClaimable(in: world)
        let rewards = claimable.previews.reduce(Balance.zero) { $0 + $1.redeemable }
        let holds = try run(services.rootHoldFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: [root.primaryHotkey]))
        let positionDetail = try run(directoryService.createDetailWrapper(for: root.primaryHotkey, subnet: rootRef))
        let rootYield = try run(services.yieldService.createRootYieldWrapper())

        let directory = try run(directoryService.createDirectoryWrapper(for: rootRef))
        let infoDetail = try run(directoryService.createDetailWrapper(for: root.primaryHotkey, subnet: rootRef))

        let operationService = try world.createStakingOperationService(networkFee: networkFee)

        let stakeFee = try run(operationService.createFeeWrapper(
            for: .rootStake(hotkey: actedOn.hotkey, amount: SubtensorFlowChainWorld.stakeAmount)
        ))

        let maxStake = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: stakeFee.amount
        )

        let preflight = try run(preflightFactory.createPreflightWrapper(
            for: coldkey,
            hotkey: actedOn.hotkey,
            netuid: SubtensorStakingPallet.rootNetuid
        ))

        let rootAvailability = try XCTUnwrap(yourBittensor.state.availability[SubtensorStakingPallet.rootNetuid])

        let maxCandidateFee = try run(operationService.createFeeWrapper(
            for: .rootUnstake(hotkey: actedOn.hotkey, amount: actedOn.stakeAlpha)
        ))

        let maxUnstake = SubtensorAmountPolicy.maxSell(positionAlpha: actedOn.stakeAlpha, availability: rootAvailability)

        let maxUnstakeOperation = SubtensorAmountPolicy.rootMaxUnstake(for: SubtensorRootMaxUnstakeInput(
            hotkeys: [actedOn.hotkey],
            positionAlpha: actedOn.stakeAlpha,
            availability: rootAvailability,
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: maxCandidateFee.amount,
            existentialDeposit: SubtensorFlowActiveStake.existentialDeposit,
            isOwnHotkey: preflight.hotkeyOwner == coldkey,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        ))

        let unstakePlan = SubtensorAmountPolicy.sellPlan(for: SubtensorSellPlanInput(
            requestedAlpha: unstakeAmount,
            positionAlpha: actedOn.stakeAlpha,
            availability: rootAvailability,
            minimumTaoOut: unstakeAmount,
            sellLimitPrice: SubtensorStakingPallet.alphaPriceScale,
            isOwnHotkey: preflight.hotkeyOwner == coldkey,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        ))

        let unstakeFee = try run(operationService.createFeeWrapper(
            for: .rootUnstake(hotkey: actedOn.hotkey, amount: unstakeAmount)
        ))

        let addStakeResult = try submit(
            .rootStake(hotkey: actedOn.hotkey, amount: SubtensorFlowChainWorld.stakeAmount),
            in: world,
            events: [
                SubtensorFlowExtrinsic.stakeAdded(
                    hotkey: aster,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    tao: 5_000_000_000,
                    alpha: 5_000_000_000,
                    poolFee: 0
                ),
                SubtensorFlowExtrinsic.networkFeePaid(paidNetworkFee)
            ]
        )

        let unstakeResult = try submit(
            .rootUnstake(hotkey: actedOn.hotkey, amount: unstakeAmount),
            in: world,
            events: [
                SubtensorFlowExtrinsic.stakeRemoved(
                    hotkey: aster,
                    netuid: SubtensorStakingPallet.rootNetuid,
                    tao: 10_000_000_000,
                    alpha: 10_000_000_000,
                    poolFee: 0
                ),
                SubtensorFlowExtrinsic.networkFeePaid(paidNetworkFee)
            ]
        )

        world.sharedState.throttle()

        assertYourBittensor(yourBittensor)

        XCTAssertEqual(root.primaryHotkey, aster)
        XCTAssertEqual(root.positions.map(\.isRegistered), [true])
        XCTAssertEqual(claimable, try SubtensorFlowActiveStake.expectedClaimable())
        XCTAssertEqual(rewards, 420_300_000)
        XCTAssertEqual(holds, [aster: SubtensorRootHold(interval: 0, lastStakeBlock: 9_139_000)])
        XCTAssertEqual(holds[aster]?.isUnlocked(at: BittensorApiFixtureWorld.headBlock), true)
        XCTAssertEqual(positionDetail, SubtensorValidatorDetail(item: try asterRoot(name: nil), identity: identity("Aster Stake")))
        XCTAssertEqual(rootYield, try fixtureRootYield())
        XCTAssertEqual(rootYield?.annualRate, try decimal("0.138421"))

        XCTAssertEqual(directory, SubtensorValidatorDirectory(
            subnet: SubtensorSubnetRef(netuid: 0, registeredAt: 0),
            items: [
                try rootItem(.halcyon, uid: 40, take: 7864, name: "Halcyon Pool"),
                try rootItem(.ember, uid: 27, take: 9830, name: "Ember Labs"),
                try asterRoot(name: "Aster Stake"),
                try rootItem(.blueHarbor, uid: 11, take: 0, name: "Blue Harbor")
            ],
            listStamp: SubtensorBackendStamp(asOf: try date("2026-09-24T08:00:00Z"), freshness: .fresh),
            isPartial: false,
            isEnrichmentTruncated: false,
            chainBlock: 9_140_000
        ))

        XCTAssertEqual(
            infoDetail,
            SubtensorValidatorDetail(item: try asterRoot(name: "Aster Stake"), identity: identity("Aster Stake"))
        )

        XCTAssertEqual(stakeFee.amount, networkFee)
        XCTAssertEqual(maxStake, 48_188_500_000)
        XCTAssertEqual(actedOn.stakeAlpha + SubtensorFlowChainWorld.stakeAmount, 25_000_000_000)

        XCTAssertEqual(maxUnstake, 20_000_000_000)
        XCTAssertEqual(maxUnstakeOperation, .rootUnstake(hotkey: aster, amount: 20_000_000_000))
        XCTAssertEqual(unstakePlan, .partial)
        XCTAssertEqual([maxCandidateFee.amount, unstakeFee.amount], [networkFee, networkFee])
        XCTAssertEqual(BigInt(actedOn.stakeAlpha) - BigInt(unstakeAmount), 10_000_000_000)

        XCTAssertEqual(addStakeResult.calls, [
            SubtensorFlowExtrinsic.addStake(hotkey: aster, netuid: SubtensorStakingPallet.rootNetuid, amount: 5_000_000_000)
        ])

        XCTAssertEqual(addStakeResult.outcome, rootOutcome(tao: SubtensorFlowChainWorld.stakeAmount))

        XCTAssertEqual(unstakeResult.calls, [
            SubtensorFlowExtrinsic.removeStake(
                hotkey: aster,
                netuid: SubtensorStakingPallet.rootNetuid,
                amount: 10_000_000_000
            )
        ])

        XCTAssertEqual(unstakeResult.outcome, rootOutcome(tao: unstakeAmount))
        verify(world.positionsSyncService, times(2)).refresh()

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets/0/validators",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://earn-config.test/earn_config.json",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=7"
        ])

        assertAttestedRequests(
            world,
            paths: ["/v1/bittensor/subnets", "/v1/bittensor/yields/root", "/v1/bittensor/subnets/0/validators"]
        )
    }

    func testBackendDownStillStakesOnRootOnTheConfigPresetWithoutARate() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)

        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveBittensor(
            "/subnets/0/validators",
            reply: .apiError(statusCode: 503, code: "dataset_unavailable", requestId: "req-root-down")
        )
        SubtensorFlowURLProtocol.serveBittensor(
            "/yields/root?page=1&pageSize=100",
            reply: .apiError(statusCode: 503, code: "dataset_unavailable", requestId: "req-root-yield-down")
        )

        let preset = try XCTUnwrap(
            try run(world.createPresetFactory().createPresetWrapper(for: rootRef, existingHotkey: nil))
        )

        let rootYield = try run(services.yieldService.createRootYieldWrapper())
        let stake = SubtensorStakingOperation.rootStake(hotkey: preset.hotkey, amount: SubtensorFlowChainWorld.stakeAmount)
        let fee = try run(world.createStakingOperationService(networkFee: networkFee).createFeeWrapper(for: stake))

        let result = try submit(stake, in: world, events: [
            SubtensorFlowExtrinsic.stakeAdded(
                hotkey: aster,
                netuid: SubtensorStakingPallet.rootNetuid,
                tao: 5_000_000_000,
                alpha: 5_000_000_000,
                poolFee: 0
            ),
            SubtensorFlowExtrinsic.networkFeePaid(paidNetworkFee)
        ])

        XCTAssertEqual(preset, try asterRoot(name: nil))
        XCTAssertNil(rootYield)
        XCTAssertEqual(fee.amount, networkFee)

        XCTAssertEqual(result.calls, [
            SubtensorFlowExtrinsic.addStake(hotkey: aster, netuid: SubtensorStakingPallet.rootNetuid, amount: 5_000_000_000)
        ])

        XCTAssertEqual(result.outcome, rootOutcome(tao: SubtensorFlowChainWorld.stakeAmount))

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/subnets/0/validators",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://earn-config.test/earn_config.json"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/subnets/0/validators", "/v1/bittensor/yields/root"])
    }

    func testRootValidatorInfoKeepsChainValuesWhenTheBackendIsDown() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let directoryService = services.validatorDirectoryService
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)

        world.stubSubnets(try SubtensorFlowActiveStake.subnetsInfo())
        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveBittensor(
            "/subnets/0/validators",
            reply: .apiError(statusCode: 503, code: "dataset_unavailable", requestId: "req-f4-down")
        )
        SubtensorFlowURLProtocol.serveBittensor(
            "/yields/root?page=1&pageSize=100",
            reply: .apiError(statusCode: 503, code: "dataset_unavailable", requestId: "req-f4-root-down")
        )

        world.sharedState.setup(for: SubtensorFlowChainWorld.coldkeyAccount())
        feed.publish(try SubtensorFlowActiveStake.state())

        let root = try XCTUnwrap(SubtensorPortfolioBuilder.build(state: try awaitPositions(in: world)).root)
        let rootRef = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)

        let directoryError = runError(directoryService.createDirectoryWrapper(for: rootRef))
        let detail = try run(directoryService.createDetailWrapper(for: root.primaryHotkey, subnet: rootRef))
        let rootYield = try run(services.yieldService.createRootYieldWrapper())
        let retriedDirectoryError = runError(directoryService.createDirectoryWrapper(for: rootRef))

        world.sharedState.throttle()

        XCTAssertEqual(root.primaryHotkey, aster)
        XCTAssertTrue(isDatasetUnavailable(directoryError, requestId: "req-f4-down"))
        XCTAssertTrue(isDatasetUnavailable(retriedDirectoryError, requestId: "req-f4-down"))
        XCTAssertEqual(detail.item, try asterRoot(name: nil))
        XCTAssertNil(rootYield)

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/subnets/0/validators",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://earn-config.test/earn_config.json"
        ])

        assertAttestedRequests(
            world,
            paths: ["/v1/bittensor/subnets/0/validators", "/v1/bittensor/yields/root"]
        )
    }
}

private extension SubtensorActiveRootFlowTests {
    func rootOutcome(tao: Balance) -> SubtensorStakingOperationOutcome {
        SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: tao, alpha: tao, netuid: SubtensorStakingPallet.rootNetuid),
            novaFeePaid: nil,
            alphaFeePaid: nil,
            networkFeePaid: Balance(paidNetworkFee),
            extrinsicHash: SubtensorFlowExtrinsic.extrinsicHash,
            blockHash: SubtensorFlowExtrinsic.blockHash
        )
    }

    func isDatasetUnavailable(_ error: Error?, requestId: String) -> Bool {
        guard case let .datasetUnavailable(receivedRequestId)? = error as? BittensorApiError else {
            return false
        }

        return receivedRequestId == requestId
    }
}
