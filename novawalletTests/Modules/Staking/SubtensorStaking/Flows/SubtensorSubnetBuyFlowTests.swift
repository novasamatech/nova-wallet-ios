import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetBuyFlowTests: SubtensorFlowTestCase {
    private let grossTao: Balance = 10_000_000_000
    private let novaFee: UInt64 = 84_283_589
    private let stakedTao: UInt64 = 9_915_716_411
    private let boughtAlpha: UInt64 = 180_322_068_005
    private let poolFee: UInt64 = 4_993_036
    private let limitPrice: UInt64 = 55_236_040

    private let chutesQuote = SubtensorQuote(
        args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 9_915_716_411)),
        sim: SubtensorStakingPallet.SimSwapResult(
            taoAmount: 9_915_716_411,
            alphaAmount: 180_322_068_005,
            taoFee: 4_993_036,
            alphaFee: 0,
            taoSlippage: 0,
            alphaSlippage: 0
        ),
        spotPrice: 54_961_234,
        feeRate: 33,
        capturedAt: Date(timeIntervalSince1970: 1_790_000_000)
    )

    func testChoosingChutesMyselfBuysOnTheRecommendedValidatorWithTheNovaFeeTransferInTheBatchAndLandsOnYourBittensor() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)
        let cinder = try SubtensorFlowChainWorld.hotkey(.cinder)
        let beneficiary = try SubtensorFlowChainWorld.productionNovaFeeBeneficiary()

        world.stubSubnets(try SubtensorFlowChainWorld.subnetsInfo())
        world.stubQuotes([chutesQuote])
        world.stubClaimPreviews([])
        SubtensorFlowURLProtocol.serveSubnetLogos()
        SubtensorFlowURLProtocol.serveFixture(.subnets)
        SubtensorFlowURLProtocol.serveFixture(.rootYield(page: 1, pageSize: 100))
        SubtensorFlowURLProtocol.serveFixture(.rankedSubnets)
        SubtensorFlowURLProtocol.serveFixture(.recommendations)
        SubtensorFlowURLProtocol.serveFixture(.validators(netuid: 64))
        SubtensorFlowURLProtocol.serveFixture(.alphaYield(netuid: 64, page: 1, pageSize: 100))
        try SubtensorFlowActiveStake.serveCharts()

        world.sharedState.setup(for: SubtensorFlowChainWorld.coldkeyAccount())
        feed.publish(Multistaking.SubtensorStakingState(positions: [], prices: [:], availability: [:]))

        let catalogue = try run(services.catalogueService.createCatalogueWrapper())

        let listed = SubtensorSubnetListBuilder.entries(
            from: catalogue,
            subnetsInfo: try fetchSubnetsInfo(from: world.sharedState.subnetsService)
        )

        let rootBar = try run(services.yieldService.createRootYieldWrapper())
        let ranking = try XCTUnwrap(try run(services.rankingViewService.createRankingViewWrapper()))
        let chutes = try XCTUnwrap(listed.first { $0.subnet.netuid == 64 }?.subnet)

        let detailsPreset = try XCTUnwrap(
            try run(world.createPresetFactory().createPresetWrapper(for: chutes.ref, existingHotkey: nil))
        )

        let alphaYields = try run(services.yieldService.createAlphaYieldsWrapper(for: chutes.netuid))

        let directory = try run(services.validatorDirectoryService.createDirectoryWrapper(for: chutes.ref))
        let picked = try XCTUnwrap(directory.items.first { $0.hotkey == detailsPreset.hotkey })

        let amountQuote = try run(services.tradeQuoteFactory.createBuyQuoteWrapper(
            netuid: chutes.netuid,
            grossTao: grossTao,
            tolerance: services.earnSettings.slippageTolerance
        ))

        let amountBuy = SubtensorStakingOperation.subnetBuy(
            hotkey: picked.hotkey,
            netuid: chutes.netuid,
            grossTao: grossTao,
            limitPrice: amountQuote.limitPrice
        )

        let amountFee = try run(
            world.createStakingOperationService(networkFee: networkFee).createFeeWrapper(for: amountBuy)
        )

        let maxBuy = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: amountFee.amount
        )

        let confirmQuote = try run(services.tradeQuoteFactory.createBuyQuoteWrapper(
            netuid: chutes.netuid,
            grossTao: grossTao,
            tolerance: services.earnSettings.slippageTolerance
        ))

        let confirmBuy = SubtensorStakingOperation.subnetBuy(
            hotkey: picked.hotkey,
            netuid: chutes.netuid,
            grossTao: grossTao,
            limitPrice: confirmQuote.limitPrice
        )

        let productionFeeCalculator = try world.createProductionWiredNovaFeeCalculator()

        feed.publishOnRefresh(Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: cinder,
                    netuid: 64,
                    stakeAlpha: Balance(boughtAlpha),
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [64: 54_961_234],
            availability: [
                64: SubtensorStakingPallet.StakeAvailability(
                    total: Balance(boughtAlpha),
                    locked: 0,
                    available: Balance(boughtAlpha)
                )
            ]
        ))

        let result = try submit(confirmBuy, in: world, events: [
            SubtensorFlowExtrinsic.stakeAdded(hotkey: cinder, netuid: 64, tao: stakedTao, alpha: boughtAlpha, poolFee: poolFee),
            SubtensorFlowExtrinsic.transfer(to: beneficiary, amount: novaFee),
            SubtensorFlowExtrinsic.networkFeePaid(paidNetworkFee)
        ])

        let yourBittensor = try openYourBittensor(in: world)

        world.sharedState.throttle()

        XCTAssertEqual(listed.count, 10)
        XCTAssertEqual(chutes.ref, SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295))
        XCTAssertEqual(chutes.name, "Chutes")
        XCTAssertEqual(chutes.symbol, "ش")
        XCTAssertEqual(rootBar?.annualRate, try decimal("0.138421"))
        XCTAssertEqual(ranking.subnet(for: 64)?.riskClass, .balanced)

        XCTAssertEqual(detailsPreset, try cinderItem(name: "Cinder Node"))
        XCTAssertEqual(picked, try cinderItem(name: "Cinder Node"))
        XCTAssertEqual(SubtensorAlphaApyFormatter.annualRate(for: cinder, in: alphaYields), try decimal("0.190417"))

        XCTAssertEqual(amountQuote, SubtensorTradeQuote(
            quote: chutesQuote,
            amountIn: grossTao,
            novaFee: SubtensorNovaFee(amount: Balance(novaFee), beneficiary: beneficiary),
            expectedOut: Balance(boughtAlpha),
            swapMinimumOut: 179_424_943_841,
            minimumOut: 179_424_943_841,
            limitPrice: Balance(limitPrice)
        ))

        XCTAssertEqual(amountFee.amount, networkFee)
        XCTAssertEqual(maxBuy, 48_188_500_000)
        XCTAssertEqual(
            try productionFeeCalculator.buyFee(grossTao: grossTao),
            SubtensorNovaFee(amount: Balance(novaFee), beneficiary: beneficiary)
        )

        XCTAssertNil(try productionFeeCalculator.buyFee(grossTao: 0))

        XCTAssertEqual(result.calls, [
            SubtensorFlowExtrinsic.batchAll([
                SubtensorFlowExtrinsic.addStakeLimit(hotkey: cinder, netuid: 64, amount: stakedTao, limitPrice: limitPrice),
                try SubtensorFlowExtrinsic.transferKeepAlive(to: beneficiary, amount: Balance(novaFee))
            ])
        ])

        XCTAssertEqual(result.outcome, SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: Balance(stakedTao), alpha: Balance(boughtAlpha), netuid: 64),
            novaFeePaid: Balance(novaFee),
            alphaFeePaid: nil,
            networkFeePaid: Balance(paidNetworkFee),
            extrinsicHash: SubtensorFlowExtrinsic.extrinsicHash,
            blockHash: SubtensorFlowExtrinsic.blockHash
        ))

        verify(world.positionsSyncService).refresh()

        XCTAssertNil(yourBittensor.portfolio.root)
        XCTAssertEqual(yourBittensor.portfolio.subnets.map(\.netuid), [64])
        XCTAssertEqual(yourBittensor.portfolio.subnets.map(\.primaryHotkey), [cinder])
        XCTAssertEqual(yourBittensor.portfolio.subnets.map(\.totalAlpha), [Balance(boughtAlpha)])
        XCTAssertEqual(yourBittensor.portfolio.subnets.map(\.taoValue), [9_910_723_374])
        XCTAssertEqual(try yourBittensor.subnet(netuid: 64).name, "Chutes")

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/recommendations",
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets/64/validators",
            "GET https://bittensor.test/v1/bittensor/subnets/64/yields/alpha?page=1&pageSize=100",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://subnet-logos.test/subnets.json",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/chutes/market_chart?vs_currency=usd&days=30",
            "GET \(SubtensorFlowHost.priceAPI)/coins/markets?vs_currency=usd&category=bittensor-subnets&per_page=250&page=1&sparkline=true&price_change_percentage=7d"
        ])

        assertAttestedRequests(
            world,
            paths: [
                "/v1/bittensor/subnets",
                "/v1/bittensor/yields/root",
                "/v1/bittensor/recommendations/subnets",
                "/v1/bittensor/subnets/64/validators",
                "/v1/bittensor/recommendations",
                "/v1/bittensor/subnets/64/yields/alpha"
            ]
        )
    }
}
