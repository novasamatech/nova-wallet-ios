import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetStrategyFlowTests: SubtensorFlowTestCase {
    private let generationId = BittensorApiFixtureWorld.generationId

    func testSubnetStrategyFlowPicksTheVerifiedChutesPairAndPricesTheBuyNetOfTheNovaFee() throws {
        let world = try SubtensorFlowWorld(novaFeeBeneficiary: SubtensorFlowChainWorld.novaFeeBeneficiary)
        let services = world.earnServices
        let engine = try world.stubRootEngine(grossRate: decimal("0.07"), netRates: [0: decimal("0.07")])

        world.stubSubnets(try SubtensorFlowChainWorld.subnetsInfo())
        world.stubQuotes([SubtensorFlowChainWorld.chutesBuyQuote])
        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveFixture(.recommendations)
        SubtensorFlowURLProtocol.serveFixture(.rankedSubnets)

        let bannerConfig = try run(services.earnConfigProvider.createConfigWrapper())

        let offers = try run(services.discoveryService.createStrategyOffersWrapper())
        world.clock.advance(by: 30)
        let verified = try run(services.recommendationService.createVerifiedRecommendationsWrapper())
        let strategiesAge = verified.generation.shownAge(at: world.clock.now)
        services.earnSettings.lastStrategy = .balanced

        let candidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .balanced))
        let ranked = try run(services.recommendationService.createRankedSubnetsWrapper())
        world.clock.advance(by: 15)
        let pickAge = ranked.generation.shownAge(at: world.clock.now)
        let catalogue = try fetchSubnetsInfo(from: world.sharedState.subnetsService)
        let logos = SubtensorSubnetLogoResolver(config: try run(services.earnConfigProvider.createConfigWrapper()))
        let slippage = services.earnSettings.slippageTolerance

        let buyQuote = try run(services.tradeQuoteFactory.createBuyQuoteWrapper(
            netuid: 64,
            grossTao: SubtensorFlowChainWorld.stakeAmount,
            tolerance: slippage
        ))

        let productionBuyFee = try world.createProductionWiredNovaFeeCalculator().buyFee(
            grossTao: SubtensorFlowChainWorld.stakeAmount
        )

        let fee = try run(world.createStakingOperationService(networkFee: networkFee).createFeeWrapper(
            for: .subnetBuy(
                hotkey: SubtensorFlowChainWorld.hotkey(.cinder),
                netuid: 64,
                grossTao: SubtensorFlowChainWorld.stakeAmount,
                limitPrice: buyQuote.limitPrice
            )
        ))

        let maxStake = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: fee.amount
        )

        world.clock.advance(by: 60)
        let revisitedOffers = try run(services.discoveryService.createStrategyOffersWrapper())
        let revisitedVerified = try run(services.recommendationService.createVerifiedRecommendationsWrapper())
        let revisitedCandidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .balanced))
        let revisitedRanked = try run(services.recommendationService.createRankedSubnetsWrapper())

        XCTAssertEqual(bannerConfig.headlineMaxAnnualRate, try decimal("0.40"))
        XCTAssertEqual(bannerConfig.entry?.enabled, true)

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(
                kind: .steady,
                rootNetworkRate: SubtensorRate(annualRate: try decimal("0.07"), source: .chainNetworkAverage(isNetOfTake: true)),
                isAvailable: true
            ),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: true),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: true)
        ])

        XCTAssertEqual(verified.droppedByGate, [.takeAboveMax: 1])
        XCTAssertEqual(verified.generation.stamp, SubtensorBackendStamp(asOf: try date("2026-09-24T09:23:00Z"), freshness: .fresh))
        XCTAssertFalse(verified.generation.isServedFromMemory)
        XCTAssertEqual(strategiesAge, 450)
        XCTAssertEqual(services.earnSettings.lastStrategy, .balanced)

        XCTAssertEqual(candidates.kind, .balanced)
        XCTAssertEqual(candidates.generationId, generationId)
        XCTAssertEqual(candidates.candidates.map(pairSummary), [
            PairSummary(
                netuid: 64,
                hotkey: try SubtensorFlowChainWorld.hotkey(.cinder),
                validatorName: "Cinder Node",
                verification: SubtensorPairVerification(uid: 138, take: takeFraction(6553), blocksSinceUpdate: 30)
            ),
            PairSummary(
                netuid: 4,
                hotkey: try SubtensorFlowChainWorld.hotkey(.fjord),
                validatorName: "Fjord Validators",
                verification: SubtensorPairVerification(uid: 237, take: takeFraction(3276), blocksSinceUpdate: 57)
            )
        ])

        let chutes = try XCTUnwrap(ranked.subnet(for: 64))
        XCTAssertEqual(chutes.riskClass, .balanced)
        XCTAssertEqual(chutes.ageBlocks, 4_608_585)
        XCTAssertEqual(chutes.taoIn, try decimal("187432.117"))
        XCTAssertEqual(chutes.breakdown?.volatility.raw, try decimal("0.0312"))
        XCTAssertEqual(chutes.breakdown?.volatility.normalized, try decimal("24.92"))
        XCTAssertEqual(chutes.eligibleValidators, 14)
        XCTAssertEqual(chutes.scoredValidators, 16)
        XCTAssertEqual(ranked.generation.id, generationId)
        XCTAssertEqual(ranked.generation.stamp, verified.generation.stamp)
        XCTAssertEqual(pickAge, 435)

        let chutesInfo = try XCTUnwrap(catalogue.subnets.first { $0.netuid == 64 })
        XCTAssertEqual(chutesInfo.displayName, "Chutes")
        XCTAssertEqual(chutesInfo.displaySymbol, "ش")
        XCTAssertEqual(chutesInfo.networkRegisteredAt, 4_531_295)
        XCTAssertEqual(
            logos.url(for: SubtensorSubnetRef(netuid: 64, registeredAt: chutesInfo.networkRegisteredAt))?.absoluteString,
            SubtensorFlowChainWorld.chutesLogo
        )

        let targonInfo = try XCTUnwrap(catalogue.subnets.first { $0.netuid == 4 })
        XCTAssertEqual(ranked.subnet(for: 4)?.ageBlocks, 7_728_429)
        XCTAssertEqual(targonInfo.displayName, "Targon")
        XCTAssertEqual(targonInfo.displaySymbol, "δ")
        XCTAssertEqual(targonInfo.networkRegisteredAt, 1_411_451)
        XCTAssertNil(logos.url(for: SubtensorSubnetRef(netuid: 4, registeredAt: targonInfo.networkRegisteredAt)))

        XCTAssertEqual(slippage, BigRational(numerator: 5, denominator: 1000))
        XCTAssertEqual(buyQuote, SubtensorTradeQuote(
            quote: SubtensorFlowChainWorld.chutesBuyQuote,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: SubtensorFlowChainWorld.novaFeeBeneficiary),
            expectedOut: 90_150_000_000,
            minimumOut: 89_712_471_929,
            limitPrice: 55_236_040
        ))
        verify(world.quoteOperationFactory).createQuoteWrapper(
            for: equal(to: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)))
        )
        XCTAssertEqual(fee.amount, networkFee)
        XCTAssertEqual(maxStake, 48_188_500_000)
        XCTAssertEqual(productionBuyFee, SubtensorNovaFee(
            amount: 42_141_794,
            beneficiary: try SubtensorFlowChainWorld.placeholderNovaFeeBeneficiary()
        ))

        XCTAssertEqual(revisitedOffers, offers)
        XCTAssertEqual(revisitedVerified, verified)
        XCTAssertEqual(revisitedCandidates, candidates)
        XCTAssertEqual(revisitedRanked, ranked)
        verify(engine, times(2)).rootAnnualReturn(take: equal(to: UInt16(0)))
        verify(engine, never()).rootAnnualReturn()

        XCTAssertEqual(requestLines(), [
            "GET https://earn-config.test/earn_config.json",
            "GET https://bittensor.test/v1/bittensor/recommendations",
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations", "/v1/bittensor/recommendations/subnets"])
    }

    func testSubnetStrategyFlowWithUnpublishedRecommendationsAndAvailableConfigOffersOnlyTheConfigSteady() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let engine = try world.stubRootEngine(grossRate: decimal("0.07"), netRates: [11796: decimal("0.0574")])

        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveBittensor("/recommendations", reply: .notFoundPlainText())
        SubtensorFlowURLProtocol.serveBittensor("/recommendations/subnets", reply: .notFoundPlainText())

        _ = try run(services.earnConfigProvider.createConfigWrapper())
        let offers = try run(services.discoveryService.createStrategyOffersWrapper())
        let candidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .balanced))
        let rankingError = runError(services.recommendationService.createRankedSubnetsWrapper())
        let retriedCandidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .balanced))
        let retriedRankingError = runError(services.recommendationService.createRankedSubnetsWrapper())

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(
                kind: .steady,
                rootNetworkRate: SubtensorRate(annualRate: try decimal("0.0574"), source: .chainNetworkAverage(isNetOfTake: true)),
                isAvailable: true
            ),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: false),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: false)
        ])

        verify(engine).rootAnnualReturn(take: equal(to: UInt16(11796)))
        verify(engine, never()).rootAnnualReturn()

        XCTAssertEqual(candidates, SubtensorPickCandidates(kind: .balanced, candidates: [], generationId: nil))
        XCTAssertEqual(retriedCandidates, candidates)
        XCTAssertTrue(isRouteNotPublished(rankingError))
        XCTAssertTrue(isRouteNotPublished(retriedRankingError))

        XCTAssertEqual(requestLines(), [
            "GET https://earn-config.test/earn_config.json",
            "GET https://bittensor.test/v1/bittensor/recommendations",
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations", "/v1/bittensor/recommendations/subnets"])
    }
}

private extension SubtensorSubnetStrategyFlowTests {
    struct PairSummary: Equatable {
        let netuid: UInt16
        let hotkey: AccountId
        let validatorName: String?
        let verification: SubtensorPairVerification
    }

    func pairSummary(_ candidate: SubtensorPickCandidate) -> PairSummary? {
        guard case let .pair(pair) = candidate else {
            return nil
        }

        return PairSummary(
            netuid: pair.netuid,
            hotkey: pair.hotkey,
            validatorName: pair.validatorName,
            verification: pair.verification
        )
    }
}
