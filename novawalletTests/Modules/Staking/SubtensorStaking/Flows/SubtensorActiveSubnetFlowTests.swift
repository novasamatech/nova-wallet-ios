import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorActiveSubnetFlowTests: SubtensorFlowTestCase {
    private let sellAlpha: Balance = 56_200_000_000

    private let chutesBuyQuote = SubtensorQuote(
        args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)),
        sim: SubtensorStakingPallet.SimSwapResult(
            taoAmount: 4_957_858_206,
            alphaAmount: 67_054_958_000,
            taoFee: 2_496_518,
            alphaFee: 0,
            taoSlippage: 0,
            alphaSlippage: 0
        ),
        spotPrice: SubtensorFlowActiveStake.chutesSpotPrice,
        feeRate: 33,
        capturedAt: Date(timeIntervalSince1970: 1_790_208_000)
    )

    private let chutesSellQuote = SubtensorQuote(
        args: SubtensorQuoteArgs(netuid: 64, direction: .unstake(alphaIn: 56_200_000_000)),
        sim: SubtensorStakingPallet.SimSwapResult(
            taoAmount: 4_145_000_000,
            alphaAmount: 56_200_000_000,
            taoFee: 0,
            alphaFee: 28_299_382,
            taoSlippage: 0,
            alphaSlippage: 0
        ),
        spotPrice: SubtensorFlowActiveStake.chutesSpotPrice,
        feeRate: 33,
        capturedAt: Date(timeIntervalSince1970: 1_790_208_000)
    )

    func testActiveSubnetBuyAndSellReachConfirmFromChainQuotes() throws {
        let world = try startWorld()

        SubtensorFlowURLProtocol.serveFixture(.rankedSubnets)

        let screens = try openChutesPosition(in: world)
        let ranked = try XCTUnwrap(screens.ranked)
        let chutesRanking = try XCTUnwrap(ranked.subnet(for: 64))
        let productionFeeCalculator = try world.createProductionWiredNovaFeeCalculator()

        let productionFees = [
            try productionFeeCalculator.buyFee(grossTao: SubtensorFlowChainWorld.stakeAmount),
            try productionFeeCalculator.sellFee(quotedTaoOut: chutesSellQuote.sim.taoAmount)
        ]

        XCTAssertEqual(screens.entryConfig.entry?.enabled, true)
        assertYourBittensor(screens.yourBittensor)

        XCTAssertNil(screens.rankingError)
        XCTAssertEqual(chutesRanking.status, .scored)
        XCTAssertTrue(chutesRanking.isEligible)
        XCTAssertEqual(chutesRanking.riskClass, .balanced)
        XCTAssertEqual(chutesRanking.subnetRisk, try decimal("18.96"))
        XCTAssertEqual(chutesRanking.ageBlocks, 4_608_585)
        XCTAssertEqual(chutesRanking.taoIn, try decimal("187432.117"))
        XCTAssertEqual(chutesRanking.breakdown?.poolDepth.raw, try decimal("187432.117"))
        XCTAssertEqual(chutesRanking.breakdown?.age.raw, try decimal("4608585"))
        XCTAssertEqual(chutesRanking.breakdown?.volatility.raw, try decimal("0.0312"))
        XCTAssertEqual(chutesRanking.scoredValidators, 16)
        XCTAssertEqual(chutesRanking.eligibleValidators, 14)
        XCTAssertEqual(
            ranked.generation.sourceBlockNumber - (chutesRanking.ageBlocks ?? 0),
            screens.chutesInfo.networkRegisteredAt
        )
        XCTAssertEqual(ranked.generation.id, BittensorApiFixtureWorld.generationId)
        XCTAssertEqual(ranked.generation.sourceBlockNumber, 9_139_880)
        XCTAssertEqual(ranked.generation.ageSeconds, 420)
        XCTAssertEqual(ranked.generation.stamp, SubtensorBackendStamp(asOf: try date("2026-09-24T09:23:00Z"), freshness: .fresh))
        XCTAssertFalse(ranked.generation.isServedFromMemory)
        XCTAssertEqual(screens.rankingAge, 450)

        try assertChainValues(of: screens)

        let placeholderBeneficiary = try SubtensorFlowChainWorld.placeholderNovaFeeBeneficiary()

        XCTAssertEqual(productionFees, [
            SubtensorNovaFee(amount: 42_141_794, beneficiary: placeholderBeneficiary),
            SubtensorNovaFee(amount: 34_935_547, beneficiary: placeholderBeneficiary)
        ])
        verify(world.quoteOperationFactory).createQuoteWrapper(for: equal(to: chutesBuyQuote.args))
        verify(world.quoteOperationFactory).createQuoteWrapper(for: equal(to: chutesSellQuote.args))

        XCTAssertEqual(requestLines().sorted(), chutesPositionRequestLines)
        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations/subnets"])
    }

    func testActiveSubnetBuyKeepsChainQuotesWhenRecommendationsAreNotPublished() throws {
        let world = try startWorld()

        SubtensorFlowURLProtocol.serveBittensor("/recommendations/subnets", reply: .notFoundPlainText())

        let screens = try openChutesPosition(in: world)
        let retriedRankingError = runError(world.earnServices.recommendationService.createRankedSubnetsWrapper())

        XCTAssertNil(screens.ranked)
        XCTAssertTrue(isRouteNotPublished(screens.rankingError))
        XCTAssertTrue(isRouteNotPublished(retriedRankingError))

        try assertChainValues(of: screens)

        XCTAssertEqual(requestLines().sorted(), chutesPositionRequestLines)
        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations/subnets"])
    }
}

private extension SubtensorActiveSubnetFlowTests {
    struct ChutesPositionScreens {
        let entryConfig: SubtensorEarnConfig
        let yourBittensor: SubtensorFlowYourBittensor
        let group: SubtensorPortfolioGroup
        let soldPosition: SubtensorStakingPosition
        let chutesInfo: SubtensorStakingPallet.DynamicInfo
        let logo: URL?
        let detail: SubtensorValidatorDetail
        let weekHistory: SubtensorPriceHistoryResult
        let maxSell: Balance
        let ranked: SubtensorRankedSubnets?
        let rankingError: Error?
        let rankingAge: TimeInterval?
        let slippage: BigRational
        let buyQuote: SubtensorTradeQuote
        let buyFee: ExtrinsicFeeProtocol
        let maxBuy: Balance
        let sellQuote: SubtensorTradeQuote
        let sellFee: ExtrinsicFeeProtocol
        let sellPlan: SubtensorSellPlan
        let canPaySell: Bool
    }

    var chutesPositionRequestLines: [String] {
        [
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets",
            "GET https://earn-config.test/earn_config.json",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=30",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=7",
            "GET https://tokens-price.novasama-tech.org/api/v3/coins/chutes/market_chart?vs_currency=usd&days=7"
        ]
    }

    func startWorld() throws -> SubtensorFlowWorld {
        let world = try SubtensorFlowWorld(novaFeeBeneficiary: SubtensorFlowChainWorld.novaFeeBeneficiary)
        let feed = SubtensorFlowPositionsFeed(service: world.positionsSyncService)

        world.stubSubnets(try SubtensorFlowActiveStake.subnetsInfo())
        world.stubClaimPreviews(try SubtensorFlowActiveStake.claimPreviews())
        world.stubQuotes([chutesBuyQuote, chutesSellQuote])
        SubtensorFlowURLProtocol.serveEarnConfig()
        try SubtensorFlowActiveStake.serveCharts()

        world.sharedState.setup(for: SubtensorFlowChainWorld.coldkeyAccount())
        feed.publish(try SubtensorFlowActiveStake.state())

        return world
    }

    func openChutesPosition(in world: SubtensorFlowWorld) throws -> ChutesPositionScreens {
        let services = world.earnServices
        let coldkey = SubtensorFlowChainWorld.coldkey
        let preflightFactory = try stubPreflight(hotkeyOf: .ember, netuid: 64)

        let entryConfig = try run(services.earnConfigProvider.createConfigWrapper())

        let yourBittensor = try openYourBittensor(in: world)

        let group = try XCTUnwrap(yourBittensor.portfolio.subnets.first { $0.netuid == 64 })
        let soldPosition = try XCTUnwrap(group.positions.first)
        let catalogue = try fetchSubnetsInfo(from: world.sharedState.subnetsService)
        let chutesInfo = try XCTUnwrap(catalogue.subnets.first { $0.netuid == group.netuid })
        let chutesRef = SubtensorSubnetRef(netuid: chutesInfo.netuid, registeredAt: chutesInfo.networkRegisteredAt)
        let logo = SubtensorSubnetLogoResolver(config: try run(services.earnConfigProvider.createConfigWrapper()))
            .url(for: chutesRef)
        let detail = try run(services.validatorDirectoryService.createDetailWrapper(
            for: group.primaryHotkey,
            subnet: chutesRef
        ))
        let weekHistory = try run(try XCTUnwrap(services.priceHistoryService).createHistoryWrapper(
            for: chutesRef,
            period: .week,
            currency: .usd
        ))
        let availability = try XCTUnwrap(yourBittensor.state.availability[group.netuid])
        let maxSell = SubtensorAmountPolicy.maxSell(positionAlpha: soldPosition.stakeAlpha, availability: availability)

        let rankingWrapper = services.recommendationService.createRankedSubnetsWrapper()
        let rankingError = runError(rankingWrapper)
        let ranked = try? rankingWrapper.targetOperation.extractNoCancellableResultData()
        world.clock.advance(by: 30)
        let rankingAge = ranked?.generation.shownAge(at: world.clock.now)
        let slippage = services.earnSettings.slippageTolerance

        let buyQuote = try run(services.tradeQuoteFactory.createBuyQuoteWrapper(
            netuid: group.netuid,
            grossTao: SubtensorFlowChainWorld.stakeAmount,
            tolerance: slippage
        ))

        let operationService = try world.createStakingOperationService(networkFee: networkFee)

        let buyFee = try run(operationService.createFeeWrapper(for: .subnetBuy(
            hotkey: group.primaryHotkey,
            netuid: group.netuid,
            grossTao: SubtensorFlowChainWorld.stakeAmount,
            limitPrice: buyQuote.limitPrice
        )))

        let maxBuy = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: buyFee.amount
        )

        let preflight = try run(preflightFactory.createPreflightWrapper(
            for: coldkey,
            hotkey: soldPosition.hotkey,
            netuid: group.netuid
        ))

        let sellQuote = try run(services.tradeQuoteFactory.createSellQuoteWrapper(
            netuid: group.netuid,
            alpha: sellAlpha,
            tolerance: slippage
        ))

        let sellFee = try run(operationService.createFeeWrapper(for: .subnetSell(
            hotkey: soldPosition.hotkey,
            netuid: group.netuid,
            alpha: sellAlpha,
            limitPrice: sellQuote.limitPrice,
            quotedTaoOut: sellQuote.quote.sim.taoAmount
        )))

        let sellPlan = SubtensorAmountPolicy.sellPlan(for: SubtensorSellPlanInput(
            requestedAlpha: sellAlpha,
            positionAlpha: soldPosition.stakeAlpha,
            availability: availability,
            minimumTaoOut: sellQuote.minimumOut,
            sellLimitPrice: sellQuote.limitPrice,
            isOwnHotkey: preflight.hotkeyOwner == coldkey,
            minStake: preflight.minStake,
            nominatorMinStake: preflight.effectiveNominatorMinStake
        ))

        let canPaySell = SubtensorAmountPolicy.canPayBatchedSell(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: sellFee.amount,
            existentialDeposit: SubtensorFlowActiveStake.existentialDeposit
        )

        world.sharedState.throttle()

        return ChutesPositionScreens(
            entryConfig: entryConfig,
            yourBittensor: yourBittensor,
            group: group,
            soldPosition: soldPosition,
            chutesInfo: chutesInfo,
            logo: logo,
            detail: detail,
            weekHistory: weekHistory,
            maxSell: maxSell,
            ranked: ranked,
            rankingError: rankingError,
            rankingAge: rankingAge,
            slippage: slippage,
            buyQuote: buyQuote,
            buyFee: buyFee,
            maxBuy: maxBuy,
            sellQuote: sellQuote,
            sellFee: sellFee,
            sellPlan: sellPlan,
            canPaySell: canPaySell
        )
    }

    func assertChainValues(of screens: ChutesPositionScreens) throws {
        let ember = try SubtensorFlowChainWorld.hotkey(.ember)
        let beneficiary = SubtensorFlowChainWorld.novaFeeBeneficiary

        XCTAssertEqual(screens.chutesInfo.displayName, "Chutes")
        XCTAssertEqual(screens.chutesInfo.displaySymbol, "ش")
        XCTAssertEqual(screens.logo?.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        XCTAssertEqual(screens.group.totalAlpha, 70_200_000_000)
        XCTAssertEqual(screens.group.taoValue, 5_180_760_000)
        XCTAssertEqual(screens.group.primaryHotkey, ember)
        XCTAssertEqual(screens.group.availability?.locked, 14_000_000_000)
        XCTAssertEqual(screens.soldPosition.hotkey, ember)
        XCTAssertTrue(screens.soldPosition.isRegistered)
        XCTAssertEqual(screens.detail, SubtensorValidatorDetail(item: try emberItem(name: nil), identity: identity("Ember Labs")))
        XCTAssertEqual(screens.maxSell, 56_200_000_000)

        guard case let .available(history) = screens.weekHistory else {
            XCTFail("Expected the Chutes week history, got \(screens.weekHistory)")
            return
        }

        XCTAssertEqual(history.period, .week)
        XCTAssertEqual(history.points.map(\.date), [
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 7),
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0)
        ])
        assertFlowDoubles(history.points.map(\.taoPerAlpha), [0.0634, 0.0738])
        assertFlowDoubles(history.points.map(\.fiatPerAlpha), [19.02, 25.2396])
        XCTAssertEqual(try flowDouble(history.changeInTao), 0.0738 / 0.0634 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(history.changeInFiat), 25.2396 / 19.02 - 1, accuracy: 1e-9)

        XCTAssertEqual(screens.slippage, BigRational(numerator: 5, denominator: 1000))
        XCTAssertEqual(screens.buyQuote, SubtensorTradeQuote(
            quote: chutesBuyQuote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: beneficiary),
            expectedOut: 67_054_958_000,
            swapMinimumOut: 66_811_763_513,
            minimumOut: 66_811_763_513,
            limitPrice: 74_169_000
        ))
        XCTAssertEqual(screens.buyFee.amount, networkFee)
        XCTAssertEqual(screens.maxBuy, 48_188_500_000)

        XCTAssertEqual(screens.sellQuote, SubtensorTradeQuote(
            quote: chutesSellQuote,
            amountIn: 56_200_000_000,
            novaFee: SubtensorNovaFee(amount: 34_935_547, beneficiary: beneficiary),
            expectedOut: 4_110_064_453,
            swapMinimumOut: 4_124_744_148,
            minimumOut: 4_089_808_601,
            limitPrice: 73_431_000
        ))
        XCTAssertEqual(screens.sellFee.amount, networkFee)
        XCTAssertEqual(screens.sellPlan, .partial)
        XCTAssertTrue(screens.canPaySell)
    }
}
