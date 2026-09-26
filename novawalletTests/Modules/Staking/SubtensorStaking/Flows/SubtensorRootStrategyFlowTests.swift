import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorRootStrategyFlowTests: SubtensorFlowTestCase {
    func testRootStrategyFlowConfirmsTheTopStablePairAtItsNetNetworkRate() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let engine = try world.stubRootEngine(grossRate: decimal("0.07"), netRates: [0: decimal("0.07")])

        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveFixture(.recommendations)

        let bannerConfig = try run(services.earnConfigProvider.createConfigWrapper())

        let offers = try run(services.discoveryService.createStrategyOffersWrapper())
        world.clock.advance(by: 30)
        let verified = try run(services.recommendationService.createVerifiedRecommendationsWrapper())
        let strategiesAge = verified.generation.shownAge(at: world.clock.now)
        services.earnSettings.lastStrategy = .steady

        let candidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .steady))
        let pick = try XCTUnwrap(candidates.candidates.first.flatMap(rootPair))
        let operationService = try world.createStakingOperationService(networkFee: networkFee)
        let stake = SubtensorStakingOperation.rootStake(hotkey: pick.hotkey, amount: SubtensorFlowChainWorld.stakeAmount)

        let pickRate = try run(services.yieldService.createRootNetworkRateWrapper(take: pick.verification.take))
        let pickFee = try run(operationService.createFeeWrapper(for: stake))

        let maxStake = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: pickFee.amount
        )

        let monthlyEarnings = SubtensorEarningsEstimator.monthly(
            amount: SubtensorFlowChainWorld.stakeAmount,
            annualRate: try XCTUnwrap(pickRate.flatMap { BigRational.fraction(from: $0.annualRate) })
        )

        let confirmRate = try run(services.yieldService.createRootNetworkRateWrapper(take: pick.verification.take))
        let confirmFee = try run(operationService.createFeeWrapper(for: stake))

        let netRate = SubtensorRate(annualRate: try decimal("0.07"), source: .chainNetworkAverage(isNetOfTake: true))

        XCTAssertEqual(bannerConfig.headlineMaxAnnualRate, try decimal("0.40"))
        XCTAssertEqual(bannerConfig.entry?.enabled, true)

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: netRate, isAvailable: true),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: true),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: true)
        ])

        XCTAssertEqual(verified.generation.stamp, SubtensorBackendStamp(asOf: try date("2026-09-24T09:23:00Z"), freshness: .fresh))
        XCTAssertEqual(verified.generation.ageSeconds, 420)
        XCTAssertEqual(strategiesAge, 450)
        XCTAssertEqual(services.earnSettings.lastStrategy, .steady)

        XCTAssertEqual(candidates.kind, .steady)
        XCTAssertEqual(candidates.generationId, BittensorApiFixtureWorld.generationId)
        XCTAssertEqual(candidates.candidates.map(rootPair), [
            RootPair(
                netuid: 0,
                subnetName: "Root",
                hotkey: try SubtensorFlowChainWorld.hotkey(.blueHarbor),
                validatorName: "Blue Harbor",
                verification: SubtensorPairVerification(uid: 11, take: takeFraction(0), blocksSinceUpdate: nil)
            ),
            RootPair(
                netuid: 0,
                subnetName: "Root",
                hotkey: try SubtensorFlowChainWorld.hotkey(.aster),
                validatorName: "Aster Stake",
                verification: SubtensorPairVerification(uid: 3, take: takeFraction(11796), blocksSinceUpdate: nil)
            ),
            RootPair(
                netuid: 0,
                subnetName: "Root",
                hotkey: try SubtensorFlowChainWorld.hotkey(.ember),
                validatorName: "Ember Labs",
                verification: SubtensorPairVerification(uid: 27, take: takeFraction(9830), blocksSinceUpdate: nil)
            )
        ])

        XCTAssertEqual(pickRate, netRate)
        XCTAssertEqual(confirmRate, netRate)
        verify(engine, times(3)).rootAnnualReturn(take: any())
        verify(engine, times(3)).rootAnnualReturn(take: equal(to: UInt16(0)))
        verify(engine, never()).rootAnnualReturn()

        XCTAssertEqual([pickFee.amount, confirmFee.amount], [networkFee, networkFee])
        XCTAssertEqual(maxStake, 48_188_500_000)
        XCTAssertEqual(monthlyEarnings, 29_166_666)
        verify(world.quoteOperationFactory, never()).createQuoteWrapper(for: any())

        XCTAssertEqual(requestLines(), [
            "GET https://earn-config.test/earn_config.json",
            "GET https://bittensor.test/v1/bittensor/recommendations"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations"])
    }

    func testRootStrategyFlowWithUnpublishedRecommendationsConfirmsTheConfigRootValidator() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let engine = try world.stubRootEngine(grossRate: decimal("0.07"), netRates: [11796: decimal("0.0574")])

        SubtensorFlowURLProtocol.serveEarnConfig()
        SubtensorFlowURLProtocol.serveBittensor("/recommendations", reply: .notFoundPlainText())

        _ = try run(services.earnConfigProvider.createConfigWrapper())
        let offers = try run(services.discoveryService.createStrategyOffersWrapper())

        let candidates = try run(services.discoveryService.createPickCandidatesWrapper(for: .steady))
        let fallback = try XCTUnwrap(candidates.candidates.first.flatMap(fallbackRoot))

        let fallbackDetail = try run(services.validatorDirectoryService.createDetailWrapper(
            for: fallback.hotkey,
            subnet: SubtensorDiscoveryService.rootSubnet
        ))

        let fallbackRate = try run(services.yieldService.createRootNetworkRateWrapper(take: fallback.take))

        let fallbackFee = try run(world.createStakingOperationService(networkFee: networkFee).createFeeWrapper(
            for: .rootStake(hotkey: fallback.hotkey, amount: SubtensorFlowChainWorld.stakeAmount)
        ))

        let maxStake = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: fallbackFee.amount
        )

        let monthlyEarnings = SubtensorEarningsEstimator.monthly(
            amount: SubtensorFlowChainWorld.stakeAmount,
            annualRate: try XCTUnwrap(fallbackRate.flatMap { BigRational.fraction(from: $0.annualRate) })
        )

        let netRate = SubtensorRate(annualRate: try decimal("0.0574"), source: .chainNetworkAverage(isNetOfTake: true))

        XCTAssertEqual(offers, [
            SubtensorStrategyOffer(kind: .steady, rootNetworkRate: netRate, isAvailable: true),
            SubtensorStrategyOffer(kind: .balanced, rootNetworkRate: nil, isAvailable: false),
            SubtensorStrategyOffer(kind: .higherUpside, rootNetworkRate: nil, isAvailable: false)
        ])

        XCTAssertEqual(
            candidates,
            SubtensorPickCandidates(kind: .steady, candidates: [.fallbackRoot(try asterRoot(name: nil))], generationId: nil)
        )

        XCTAssertEqual(fallbackDetail, SubtensorValidatorDetail(item: try asterRoot(name: nil), identity: identity("Aster Stake")))
        XCTAssertEqual(fallbackRate, netRate)
        verify(engine, times(2)).rootAnnualReturn(take: any())
        verify(engine, times(2)).rootAnnualReturn(take: equal(to: UInt16(11796)))
        verify(engine, never()).rootAnnualReturn()

        XCTAssertEqual(fallbackFee.amount, networkFee)
        XCTAssertEqual(maxStake, 48_188_500_000)
        XCTAssertEqual(monthlyEarnings, 23_916_666)

        XCTAssertEqual(requestLines(), [
            "GET https://earn-config.test/earn_config.json",
            "GET https://bittensor.test/v1/bittensor/recommendations"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/recommendations"])
    }
}

private extension SubtensorRootStrategyFlowTests {
    struct RootPair: Equatable {
        let netuid: UInt16
        let subnetName: String
        let hotkey: AccountId
        let validatorName: String?
        let verification: SubtensorPairVerification
    }

    func rootPair(_ candidate: SubtensorPickCandidate) -> RootPair? {
        guard case let .pair(pair) = candidate else {
            return nil
        }

        return RootPair(
            netuid: pair.netuid,
            subnetName: pair.subnetName,
            hotkey: pair.hotkey,
            validatorName: pair.validatorName,
            verification: pair.verification
        )
    }

    func fallbackRoot(_ candidate: SubtensorPickCandidate) -> SubtensorValidatorDirectoryItem? {
        guard case let .fallbackRoot(item) = candidate else {
            return nil
        }

        return item
    }
}
