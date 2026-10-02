import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorChooseSubnetFlowTests: SubtensorFlowTestCase {
    func testChooseSubnetFlowBuildsChutesFromChainPricesAndTheRecommendedValidator() throws {
        let world = try SubtensorFlowWorld(novaFeeBeneficiary: SubtensorFlowChainWorld.novaFeeBeneficiary)
        let services = world.earnServices
        let priceHistoryService = try XCTUnwrap(services.priceHistoryService)
        let directoryService = services.validatorDirectoryService

        world.stubSubnets(try SubtensorFlowChainWorld.subnetsInfo())
        world.stubQuotes([SubtensorFlowChainWorld.chutesBuyQuote])
        SubtensorFlowURLProtocol.serveSubnetLogos()
        SubtensorFlowURLProtocol.serveFixture(.subnets)
        SubtensorFlowURLProtocol.serveFixture(.rootYield(page: 1, pageSize: 100))
        SubtensorFlowURLProtocol.serveFixture(.rankedSubnets)
        SubtensorFlowURLProtocol.serveFixture(.recommendations)
        SubtensorFlowURLProtocol.serveFixture(.validators(netuid: 64))
        try serveWeekCharts()

        let subnetRefs = try listedSubnetRefs(in: world)
        let rootRowYield = try run(services.yieldService.createRootYieldWrapper())
        let weeklyPrices = try run(priceHistoryService.createWeeklyChangesWrapper(for: subnetRefs))
        let logos = try run(services.subnetLogosProvider.createLogosWrapper())
        let initialFavourites = services.earnSettings.favouriteSubnets

        let chutesRef = try XCTUnwrap(subnetRefs.first { $0.netuid == 64 })
        let history = try run(priceHistoryService.createHistoryWrapper(for: chutesRef, period: .week, currency: .usd))
        let ranked = try run(services.recommendationService.createRankedSubnetsWrapper())
        let preset = try XCTUnwrap(
            try run(world.createPresetFactory().createPresetWrapper(for: chutesRef, existingHotkey: nil))
        )
        let presetDetail = try run(directoryService.createDetailWrapper(for: preset.hotkey, subnet: chutesRef))
        services.earnSettings.favouriteSubnets = [chutesRef]

        let directory = try run(directoryService.createDirectoryWrapper(for: chutesRef))

        let fjordDetail = try run(directoryService.createDetailWrapper(
            for: try SubtensorFlowChainWorld.hotkey(.fjord),
            subnet: chutesRef
        ))

        let selected = try XCTUnwrap(directory.items.first { $0.hotkey == preset.hotkey })
        world.clock.advance(by: 60)
        let revisitedDirectory = try run(directoryService.createDirectoryWrapper(for: chutesRef))

        let chipsRanked = try run(services.recommendationService.createRankedSubnetsWrapper())
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
                hotkey: selected.hotkey,
                netuid: 64,
                grossTao: SubtensorFlowChainWorld.stakeAmount,
                limitPrice: buyQuote.limitPrice
            )
        ))

        let maxStake = SubtensorAmountPolicy.maxBuyOrStake(
            transferable: SubtensorFlowChainWorld.transferable,
            networkFee: fee.amount
        )

        XCTAssertEqual(rootRowYield, try fixtureRootYield())
        XCTAssertEqual(rootRowYield?.annualRate, try decimal("0.138421"))

        XCTAssertEqual(chutesRef, SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295))
        XCTAssertEqual(subnetRefs.count, 10)
        XCTAssertEqual(subnetRefs.filter { logos.url(for: $0.netuid) != nil }, [chutesRef])
        XCTAssertEqual(logos.url(for: chutesRef.netuid)?.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        assertChutesWeekPrices(weeklyPrices, chutes: chutesRef)
        XCTAssertEqual(initialFavourites, [])
        XCTAssertEqual(services.earnSettings.favouriteSubnets, [chutesRef])

        assertChutesWeekHistory(history, subnet: chutesRef)

        let chutesRanking = try XCTUnwrap(ranked.subnet(for: 64))
        XCTAssertEqual(chutesRanking.riskClass, .balanced)
        XCTAssertEqual(chutesRanking.ageBlocks, 4_608_585)
        XCTAssertEqual(chutesRanking.taoIn, try decimal("187432.117"))
        XCTAssertEqual(chutesRanking.eligibleValidators, 14)
        XCTAssertEqual(chutesRanking.scoredValidators, 16)
        XCTAssertEqual(chutesRanking.flags, [])
        XCTAssertEqual(chipsRanked, ranked)

        XCTAssertEqual(
            services.recommendationService.lastSeenClientGates(),
            SubtensorClientGates(
                maxTake: BigRational(numerator: 18, denominator: 100),
                requirePermit: true,
                requireActiveWithinCutoff: true
            )
        )

        XCTAssertEqual(preset, try cinderItem(name: "Cinder Node"))
        XCTAssertEqual(
            presetDetail,
            SubtensorValidatorDetail(item: try cinderItem(name: "Cinder Node"), identity: identity("Cinder Node"))
        )

        XCTAssertEqual(
            directory.items.map(\.hotkey),
            try hotkeys([.cinder, .fjord, .granite, .halcyon, .ember, .aster, .delta, .blueHarbor])
        )

        XCTAssertEqual(directory.items.map(\.name), [
            "Cinder Node", "Fjord Validators", nil, "Halcyon Pool", "Ember Labs", "Aster Stake", "Delta Relay", "Blue Harbor"
        ])

        XCTAssertEqual(try item(.granite, in: directory).status?.hasPermit, false)
        XCTAssertEqual(try item(.halcyon, in: directory).status?.blocksSinceUpdate, 6200)
        XCTAssertEqual(try item(.halcyon, in: directory).status?.isActive, false)
        XCTAssertEqual(try item(.delta, in: directory).take, takeFraction(11797))
        XCTAssertFalse(directory.isPartial)
        XCTAssertFalse(directory.isEnrichmentTruncated)
        XCTAssertEqual(directory.listStamp, SubtensorBackendStamp(asOf: try date("2026-09-24T08:00:00Z"), freshness: .fresh))

        XCTAssertEqual(
            fjordDetail,
            SubtensorValidatorDetail(item: try item(.fjord, in: directory), identity: identity("Fjord Validators"))
        )

        XCTAssertEqual(fjordDetail.item.name, "Fjord Validators")
        XCTAssertEqual(selected.hotkey, preset.hotkey)
        XCTAssertEqual(revisitedDirectory, directory)

        XCTAssertEqual(slippage, BigRational(numerator: 5, denominator: 1000))
        XCTAssertEqual(buyQuote, SubtensorTradeQuote(
            quote: SubtensorFlowChainWorld.chutesBuyQuote,
            amountIn: 5_000_000_000,
            novaFee: SubtensorNovaFee(amount: 42_141_794, beneficiary: SubtensorFlowChainWorld.novaFeeBeneficiary),
            expectedOut: 90_150_000_000,
            swapMinimumOut: 89_712_471_929,
            minimumOut: 89_712_471_929,
            limitPrice: 55_236_040
        ))
        verify(world.quoteOperationFactory).createQuoteWrapper(
            for: equal(to: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)))
        )
        XCTAssertEqual(productionBuyFee, SubtensorNovaFee(
            amount: 42_141_794,
            beneficiary: try SubtensorFlowChainWorld.placeholderNovaFeeBeneficiary()
        ))
        XCTAssertEqual(fee.amount, networkFee)
        XCTAssertEqual(maxStake, 48_188_500_000)

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/recommendations",
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets/64/validators",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://subnet-logos.test/subnets.json",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/chutes/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/markets?vs_currency=usd&category=bittensor-subnets&per_page=250&page=1&sparkline=true&price_change_percentage=7d"
        ])

        assertAttestedRequests(
            world,
            paths: [
                "/v1/bittensor/subnets",
                "/v1/bittensor/yields/root",
                "/v1/bittensor/recommendations/subnets",
                "/v1/bittensor/subnets/64/validators",
                "/v1/bittensor/recommendations"
            ]
        )
    }

    func testChooseSubnetFlowWithUnpublishedRecommendationsKeepsChainValuesWithoutFactorsOrPreset() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let priceHistoryService = try XCTUnwrap(services.priceHistoryService)

        world.stubSubnets(try SubtensorFlowChainWorld.subnetsInfo())
        SubtensorFlowURLProtocol.serveSubnetLogos()
        SubtensorFlowURLProtocol.serveFixture(.subnets)
        SubtensorFlowURLProtocol.serveFixture(.rootYield(page: 1, pageSize: 100))
        SubtensorFlowURLProtocol.serveBittensor("/recommendations/subnets", reply: .notFoundPlainText())
        SubtensorFlowURLProtocol.serveBittensor("/recommendations", reply: .notFoundPlainText())
        SubtensorFlowURLProtocol.serveFixture(.validators(netuid: 64))
        try serveWeekCharts()

        let subnetRefs = try listedSubnetRefs(in: world)
        let rootRowYield = try run(services.yieldService.createRootYieldWrapper())
        let weeklyPrices = try run(priceHistoryService.createWeeklyChangesWrapper(for: subnetRefs))
        let logos = try run(services.subnetLogosProvider.createLogosWrapper())

        let chutesRef = try XCTUnwrap(subnetRefs.first { $0.netuid == 64 })
        let history = try run(priceHistoryService.createHistoryWrapper(for: chutesRef, period: .week, currency: .usd))
        let factorsError = runError(services.recommendationService.createRankedSubnetsWrapper())
        let preset = try run(world.createPresetFactory().createPresetWrapper(for: chutesRef, existingHotkey: nil))

        world.clock.advance(by: 60)
        let chipsError = runError(services.recommendationService.createRankedSubnetsWrapper())

        XCTAssertTrue(isRouteNotPublished(factorsError))
        XCTAssertTrue(isRouteNotPublished(chipsError))
        XCTAssertNil(services.recommendationService.lastSeenClientGates())

        XCTAssertEqual(rootRowYield, try fixtureRootYield())
        XCTAssertEqual(subnetRefs.filter { logos.url(for: $0.netuid) != nil }, [chutesRef])
        XCTAssertEqual(logos.url(for: chutesRef.netuid)?.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        assertChutesWeekPrices(weeklyPrices, chutes: chutesRef)

        assertChutesWeekHistory(history, subnet: chutesRef)

        XCTAssertNil(preset)

        XCTAssertEqual(requestLines().sorted(), [
            "GET https://bittensor.test/v1/bittensor/recommendations",
            "GET https://bittensor.test/v1/bittensor/recommendations/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets",
            "GET https://bittensor.test/v1/bittensor/subnets/64/validators",
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://subnet-logos.test/subnets.json",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/bittensor/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/chutes/market_chart?vs_currency=usd&days=7",
            "GET \(SubtensorFlowHost.priceAPI)/coins/markets?vs_currency=usd&category=bittensor-subnets&per_page=250&page=1&sparkline=true&price_change_percentage=7d"
        ])

        assertAttestedRequests(
            world,
            paths: [
                "/v1/bittensor/subnets",
                "/v1/bittensor/yields/root",
                "/v1/bittensor/recommendations/subnets",
                "/v1/bittensor/subnets/64/validators",
                "/v1/bittensor/recommendations"
            ]
        )
    }

    func testStaleRootAndValidatorYieldsAreHiddenFromTheSubnetAndValidatorScreens() throws {
        let world = try SubtensorFlowWorld()
        let services = world.earnServices
        let ember = try SubtensorFlowChainWorld.hotkey(.ember)
        let rootRoute = BittensorApiFixtureRoute.rootYield(page: 1, pageSize: 100)
        let alphaRoute = BittensorApiFixtureRoute.alphaYield(netuid: 64, page: 1, pageSize: 100)

        SubtensorFlowURLProtocol.serveBittensor(
            "/yields/root?page=1&pageSize=100",
            reply: .bittensor(staleDocument(BittensorApiFixtureRouter.document(for: rootRoute)), route: rootRoute)
        )

        SubtensorFlowURLProtocol.serveBittensor(
            "/subnets/64/yields/alpha?page=1&pageSize=100",
            reply: .bittensor(staleDocument(BittensorApiFixtureRouter.document(for: alphaRoute)), route: alphaRoute)
        )

        let rootYield = try XCTUnwrap(try run(services.yieldService.createRootYieldWrapper()))
        let alphaYields = try run(services.yieldService.createAlphaYieldsWrapper(for: 64))

        XCTAssertEqual(rootYield.reportedRate, "13.8421")
        XCTAssertEqual(rootYield.stamp.freshness, .stale)
        XCTAssertNil(rootYield.annualRate)

        XCTAssertNotNil(alphaYields.yields[ember])
        XCTAssertEqual(alphaYields.stamp.freshness, .stale)
        XCTAssertNil(SubtensorAlphaApyFormatter.annualRate(for: ember, in: alphaYields))

        XCTAssertEqual(requestLines(), [
            "GET https://bittensor.test/v1/bittensor/yields/root?page=1&pageSize=100",
            "GET https://bittensor.test/v1/bittensor/subnets/64/yields/alpha?page=1&pageSize=100"
        ])

        assertAttestedRequests(world, paths: ["/v1/bittensor/yields/root", "/v1/bittensor/subnets/64/yields/alpha"])
    }

    func testDeviceThatFailsAppAttestGivesTheValidatorListItsOwnStateWithoutTryAgain() throws {
        let world = try SubtensorFlowWorld()
        let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
        let locale = Locale(identifier: "en")
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        stub(world.attestation.holder) { stub in
            when(stub.createEndpointWrapper()).then {
                CompoundOperationWrapper<BackendAttestationEndpoint>.createWithError(BittensorApiError.unsupportedDevice)
            }
        }

        let error = try XCTUnwrap(runError(world.earnServices.validatorDirectoryService.createDirectoryWrapper(
            for: chutesRef
        )))

        let viewModel = SubtensorValidatorListFactory(
            chainFormat: world.chainAsset.chain.chainFormat,
            assetDisplayInfo: world.chainAsset.assetDisplayInfo
        ).createErrorViewModel(for: error, locale: locale)

        XCTAssertEqual((error as? BittensorApiError)?.isDeviceBound, true)
        XCTAssertEqual(viewModel.title, strings.stakingSubtensorUiValidatorFetchFailed())
        XCTAssertEqual(viewModel.details, strings.stakingSubtensorUiValidatorFetchDeviceDetail())
        XCTAssertNil(viewModel.retryTitle)
        XCTAssertEqual(requestLines(), [])
        XCTAssertEqual(world.attestation.signatures, [])
    }
}

private extension SubtensorChooseSubnetFlowTests {
    func staleDocument(_ document: [String: Any]) -> [String: Any] {
        document.reduce(into: [String: Any]()) { result, entry in
            result[entry.key] = entry.key == "freshness" ? "STALE" : staleValue(entry.value)
        }
    }

    func staleValue(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return staleDocument(object)
        }

        return (value as? [Any])?.map(staleValue) ?? value
    }

    func serveWeekCharts() throws {
        let weekStart = try milliseconds("2026-09-17T09:00:00Z")
        let weekEnd = try milliseconds("2026-09-24T09:00:00Z")
        let chutesEnd = try decimal("23.28")

        SubtensorFlowURLProtocol.serveMarketChart(coinId: "bittensor", days: "7", points: [
            SubtensorFlowPricePoint(milliseconds: weekStart, value: 340),
            SubtensorFlowPricePoint(milliseconds: weekEnd, value: 350)
        ])

        SubtensorFlowURLProtocol.serveMarketChart(coinId: "chutes", days: "7", points: [
            SubtensorFlowPricePoint(milliseconds: weekStart, value: 20),
            SubtensorFlowPricePoint(milliseconds: weekEnd, value: chutesEnd)
        ])

        SubtensorFlowURLProtocol.serveSubnetMarkets(chutesWeekStart: 20, end: chutesEnd)
    }

    func listedSubnetRefs(in world: SubtensorFlowWorld) throws -> [SubtensorSubnetRef] {
        let catalogue = try run(world.earnServices.catalogueService.createCatalogueWrapper(forcingRefresh: false))
        let subnetsInfo = try fetchSubnetsInfo(from: world.sharedState.subnetsService)

        return SubtensorSubnetListBuilder.entries(from: catalogue, subnetsInfo: subnetsInfo).map(\.subnet.ref)
    }

    func assertChutesWeekPrices(
        _ prices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>],
        chutes: SubtensorSubnetRef
    ) {
        XCTAssertEqual(prices.count, 10)
        XCTAssertEqual(prices.values.filter { $0 == .notListed }.count, 9)

        guard case let .available(summary)? = prices[chutes] else {
            XCTFail("Expected the Chutes week prices, got \(String(describing: prices[chutes]))")
            return
        }

        XCTAssertEqual(try flowDouble(summary.change), 7915.2 / 7000 - 1, accuracy: 1e-9)
        assertFlowDoubles(summary.sparkline, [20.0 / 340, 23.28 / 350])
    }

    func assertChutesWeekHistory(_ result: SubtensorPriceHistoryResult, subnet: SubtensorSubnetRef) {
        guard case let .available(history) = result else {
            XCTFail("Expected the Chutes week history, got \(result)")
            return
        }

        XCTAssertEqual(history.subnet, subnet)
        XCTAssertEqual(history.period, .week)
        XCTAssertEqual(history.points.count, 2)
        XCTAssertEqual(try flowDouble(history.changeInTao), 7915.2 / 7000 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(history.changeInFiat), 0.164, accuracy: 1e-9)
    }

    func item(
        _ member: BittensorApiFixtureWorld.Member,
        in directory: SubtensorValidatorDirectory
    ) throws -> SubtensorValidatorDirectoryItem {
        let hotkey = try SubtensorFlowChainWorld.hotkey(member)

        return try XCTUnwrap(directory.items.first { $0.hotkey == hotkey })
    }

    func hotkeys(_ members: [BittensorApiFixtureWorld.Member]) throws -> [AccountId] {
        try members.map { try SubtensorFlowChainWorld.hotkey($0) }
    }

    func milliseconds(_ text: String) throws -> UInt64 {
        UInt64(try date(text).timeIntervalSince1970 * 1000)
    }
}
