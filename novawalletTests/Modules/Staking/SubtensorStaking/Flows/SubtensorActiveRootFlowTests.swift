import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorActiveRootFlowTests: SubtensorFlowTestCase {
    private let unstakeAmount: Balance = 10_000_000_000

    func testActiveRootAddAndUnstakeReachConfirmFromChainValues() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let directoryService = services.validatorDirectoryService
        let coldkey = SubtensorFlowChainWorld.coldkey
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)
        let preflightFactory = try stubPreflight(hotkeyOf: .aster, netuid: SubtensorStakingPallet.rootNetuid)
        let engine = try world.stubRootEngine(grossRate: decimal("0.0854"), netRates: [11796: decimal("0.07")])

        world.stubSubnets(try SubtensorFlowActiveStake.subnetsInfo())
        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        world.stubRootHolds([aster: SubtensorRootHold(interval: 0, lastStakeBlock: 9_139_000)])
        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveFixture(.validators(netuid: 0))
        try SubtensorFlowActiveStake.serveCharts()

        world.sharedState.setup(for: coldkey)
        feed.publish(try SubtensorFlowActiveStake.state())

        let yourBittensor = try openYourBittensor(in: world)

        let root = try XCTUnwrap(yourBittensor.portfolio.root)
        let actedOn = try XCTUnwrap(root.positions.first)
        let rootRef = try yourBittensor.subnetRef(netuid: 0)
        let claimable = try awaitClaimable(in: world)
        let rewards = claimable.previews.reduce(Balance.zero) { $0 + $1.redeemable }
        let holds = try run(services.rootHoldFactory.createHoldsWrapper(coldkey: coldkey, hotkeys: [root.primaryHotkey]))
        let positionDetail = try run(directoryService.createDetailWrapper(for: root.primaryHotkey, subnet: rootRef))
        let rootRate = try run(services.yieldService.createRootNetworkRateWrapper(take: positionDetail.item.take))

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
            hotkey: actedOn.hotkey,
            positionAlpha: actedOn.stakeAlpha,
            availability: rootAvailability,
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: maxCandidateFee.amount,
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

        world.sharedState.throttle()

        assertYourBittensor(yourBittensor)

        XCTAssertEqual(root.primaryHotkey, aster)
        XCTAssertEqual(root.positions.map(\.isRegistered), [true])
        XCTAssertEqual(claimable, try SubtensorFlowActiveStake.expectedClaimable())
        XCTAssertEqual(rewards, 420_300_000)
        XCTAssertEqual(holds, [aster: SubtensorRootHold(interval: 0, lastStakeBlock: 9_139_000)])
        XCTAssertEqual(holds[aster]?.isUnlocked(at: BittensorApiFixtureWorld.headBlock), true)
        XCTAssertEqual(positionDetail, SubtensorValidatorDetail(item: try asterRoot(name: nil), identity: identity("Aster Stake")))
        XCTAssertEqual(rootRate, try netRootRate())
        verify(engine).rootAnnualReturn(take: equal(to: UInt16(11796)))
        verify(engine, never()).rootAnnualReturn()

        XCTAssertEqual(directory, SubtensorValidatorDirectory(
            subnet: SubtensorSubnetRef(netuid: 0, registeredAt: 0),
            items: [
                try rootItem(.halcyon, uid: 40, take: 7864, stake: 33_000_000_000_000, name: "Halcyon Pool"),
                try rootItem(.ember, uid: 27, take: 9830, stake: 61_000_000_000_000, name: "Ember Labs"),
                try asterRoot(name: "Aster Stake"),
                try rootItem(.blueHarbor, uid: 11, take: 0, stake: 145_000_000_000_000, name: "Blue Harbor")
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

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/subnets/0/validators",
            "GET https://earn-config.test/earn_config.json",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=7"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/subnets/0/validators"])
    }

    func testRootValidatorInfoKeepsChainValuesWhenTheBackendIsDown() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let directoryService = services.validatorDirectoryService
        let aster = try SubtensorFlowChainWorld.hotkey(.aster)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)
        let engine = try world.stubRootEngine(grossRate: decimal("0.0854"), netRates: [11796: decimal("0.07")])

        world.stubSubnets(try SubtensorFlowActiveStake.subnetsInfo())
        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveBittensor(
            "/subnets/0/validators",
            reply: .apiError(statusCode: 503, code: "dataset_unavailable", requestId: "req-f4-down")
        )

        world.sharedState.setup(for: SubtensorFlowChainWorld.coldkey)
        feed.publish(try SubtensorFlowActiveStake.state())

        let root = try XCTUnwrap(SubtensorPortfolioBuilder.build(state: try awaitPositions(in: world)).root)
        let catalogue = try fetchSubnetsInfo(from: world.sharedState.subnetsService)
        let rootInfo = try XCTUnwrap(catalogue.subnets.first { $0.netuid == SubtensorStakingPallet.rootNetuid })
        let rootRef = SubtensorSubnetRef(netuid: rootInfo.netuid, registeredAt: rootInfo.networkRegisteredAt)

        let directoryError = runError(directoryService.createDirectoryWrapper(for: rootRef))
        let detail = try run(directoryService.createDetailWrapper(for: root.primaryHotkey, subnet: rootRef))
        let rootRate = try run(services.yieldService.createRootNetworkRateWrapper(take: detail.item.take))
        let retriedDirectoryError = runError(directoryService.createDirectoryWrapper(for: rootRef))

        world.sharedState.throttle()

        XCTAssertEqual(root.primaryHotkey, aster)
        XCTAssertTrue(isDatasetUnavailable(directoryError, requestId: "req-f4-down"))
        XCTAssertTrue(isDatasetUnavailable(retriedDirectoryError, requestId: "req-f4-down"))
        XCTAssertEqual(detail, SubtensorValidatorDetail(item: try asterRoot(name: nil), identity: identity("Aster Stake")))
        XCTAssertEqual(rootRate, try netRootRate())
        verify(engine).rootAnnualReturn(take: equal(to: UInt16(11796)))

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/subnets/0/validators",
            "GET https://earn-config.test/earn_config.json"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/subnets/0/validators"])
    }
}

private extension SubtensorActiveRootFlowTests {
    func netRootRate() throws -> SubtensorRate {
        SubtensorRate(annualRate: try decimal("0.07"), source: .chainNetworkAverage(isNetOfTake: true))
    }

    func isDatasetUnavailable(_ error: Error?, requestId: String) -> Bool {
        guard case let .datasetUnavailable(receivedRequestId)? = error as? BittensorApiError else {
            return false
        }

        return receivedRequestId == requestId
    }
}
