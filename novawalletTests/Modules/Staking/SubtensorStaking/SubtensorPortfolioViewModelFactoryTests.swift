import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorPortfolioViewModelFactoryTests: XCTestCase {
    func testSubnetRowAndTotalValueTheHeldAlphaAtTheCataloguePriceOverTheChainPrice() {
        var state = SubtensorPortfolioState()
        state.positions = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 7, count: 32),
                    netuid: 64,
                    stakeAlpha: 100_000_000_000,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ]
        )
        state.isCatalogueResolved = true
        state.catalogue = makeCatalogue(taoPerAlpha: 73_800_000)

        let viewModel = makeFactory().createViewModel(for: state, locale: Locale(identifier: "en"))

        guard case let .positions(header, rows) = viewModel.content else {
            XCTFail("Expected the positions layout, got \(viewModel.content)")
            return
        }

        XCTAssertEqual(header.total, "7.38 TAO")
        XCTAssertEqual(rows?.map(\.value), ["≈ 7.38 TAO"])
    }

    func testMixedUnlistedChartAndHeaderUseSelectedFiatCurrency() throws {
        let euro = Currency(id: 1, code: "EUR", name: "Euro", symbol: "€", category: .fiat, isPopular: true, coingeckoId: "eur")
        let cases: [(Currency, Decimal, [Double], String)] = [
            (.usd, 1, [6950, 7482.5, 8340], "$8,340"),
            (euro, Decimal(1) / 2, [3475, 3741.25, 4170], "€4,170")
        ]

        for (currency, scale, expected, expectedFiat) in cases {
            let state = makeMixedState(currency: currency, scale: scale)
            let header = try header(for: state, currency: currency)

            guard case let .chart(chart) = header.chart, case let .indexed(values) = chart.series else {
                XCTFail("Expected the priced mixed portfolio chart")
                continue
            }
            XCTAssertEqual(values, expected)
            XCTAssertEqual(header.total, "20 TAO")
            XCTAssertEqual(header.fiat, .loaded(expectedFiat))
            XCTAssertEqual(header.change, .loaded(SubtensorPortfolioChangeViewModel(text: "+20% · 7D", isRising: true)))
        }
    }

    func testUnlistedHoldingWithUnknownCurrentValuationKeepsChartUnavailable() throws {
        var state = makeMixedState()
        state.catalogue = makeCatalogue(taoPerAlpha: 70_000_000)

        let header = try header(for: state)

        assertUnavailable(header)
        XCTAssertEqual(header.fiat, .hidden)
    }

    func testInvalidCurrentPriceAndInsufficientHistoryKeepChartUnavailable() throws {
        for price in ["invalid", "NaN", "0", "-1"] {
            var state = makeMixedState()
            state.price = .loaded(PriceData(identifier: "bittensor", price: price, dayChange: nil, currencyId: Currency.usd.id))
            assertUnavailable(try header(for: state))
        }

        var state = makeMixedState()
        state.histories = .loaded(SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(currencyId: Currency.usd.id, items: [PriceHistoryItem(startedAt: 604_800, value: 420)]),
            subnets: [],
            notListedNetuids: [19, 64]
        ))
        assertUnavailable(try header(for: state))
        state.histories = .failed
        assertUnavailable(try header(for: state))
        state = makeMixedState()
        state.price = .loaded(nil)
        assertUnavailable(try header(for: state))
    }

    func testHistoryLoadingAndRatesUnavailablePreserveLiveTaoHeader() throws {
        var state = makeMixedState()
        state.histories = .loading
        let loading = try header(for: state)
        XCTAssertEqual(loading.total, "20 TAO")
        XCTAssertEqual(loading.chart, .loading)

        state.catalogue = nil
        let unavailable = try header(for: state)
        XCTAssertEqual(unavailable.chart, .hidden)
        XCTAssertEqual(unavailable.change, .hidden)
    }

    private func makeMixedState(currency: Currency = .usd, scale: Decimal = 1) -> SubtensorPortfolioState {
        var state = SubtensorPortfolioState()
        state.positions = Multistaking.SubtensorStakingState(positions: [
            position(netuid: 0, alpha: 10_000_000_000),
            position(netuid: 64, alpha: 100_000_000_000),
            position(netuid: 19, alpha: 60_000_000_000)
        ])
        state.isCatalogueResolved = true
        state.catalogue = SubtensorSubnetCatalogue(subnets:
            makeCatalogue(taoPerAlpha: 70_000_000).subnets + makeCatalogue(taoPerAlpha: 50_000_000, netuid: 19).subnets
        )
        state.period = .week
        state.price = .loaded(.amount(417 * scale, currencyId: currency.id))
        state.histories = .loaded(SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(currencyId: currency.id, items: [
                PriceHistoryItem(startedAt: 0, value: 400 * scale),
                PriceHistoryItem(startedAt: 302_400, value: 410 * scale),
                PriceHistoryItem(startedAt: 604_800, value: 420 * scale)
            ]),
            subnets: [SubtensorPriceHistory(
                subnet: SubtensorSubnetRef(netuid: 64, registeredAt: 1),
                period: .week,
                points: [(0.0, 5), (302_400.0, 6), (604_800.0, 8)].map { time, hundredths in
                    SubtensorPricePoint(
                        date: Date(timeIntervalSince1970: time),
                        taoPerAlpha: Decimal(hundredths) / 100,
                        fiatPerAlpha: 0
                    )
                },
                changeInTao: nil,
                changeInFiat: nil
            )],
            notListedNetuids: [19]
        ))
        return state
    }

    private func position(netuid: UInt16, alpha: Balance) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: Data(repeating: 7, count: 32), netuid: netuid, stakeAlpha: alpha,
            hotkeyEmissionPerTempo: 0, totalHotkeyAlpha: nil, isRegistered: true
        )
    }

    private func header(for state: SubtensorPortfolioState, currency: Currency = .usd) throws -> SubtensorPortfolioHeaderViewModel {
        let manager = CurrencyManagerStub()
        manager.selectedCurrency = currency
        manager.availableCurrencies = [currency]
        let factory = SubtensorPortfolioViewModelFactory(
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: manager)
        )
        let model = factory.createViewModel(for: state, locale: Locale(identifier: "en"))
        guard case let .positions(header, _) = model.content else {
            XCTFail("Expected live positions")
            throw CommonError.dataCorruption
        }
        return header
    }

    private func assertUnavailable(_ header: SubtensorPortfolioHeaderViewModel, file: StaticString = #filePath, line: UInt = #line) {
        guard case .unavailable = header.chart else {
            XCTFail("Expected unavailable chart", file: file, line: line)
            return
        }
        XCTAssertEqual(header.change, .hidden, file: file, line: line)
    }

    private func makeFactory() -> SubtensorPortfolioViewModelFactory {
        SubtensorPortfolioViewModelFactory(
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeCatalogue(taoPerAlpha: Balance, netuid: UInt16 = 64) -> SubtensorSubnetCatalogue {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorSubnetCatalogue(subnets: [
            SubtensorCatalogueSubnet(
                netuid: netuid,
                name: "Chutes",
                symbol: "ش",
                networkRegisteredAt: 4_531_295,
                tempo: 360,
                ownerColdkey: "",
                ownerHotkey: "",
                links: SubtensorSubnetLinks(
                    githubRepo: "",
                    subnetContact: "",
                    subnetUrl: "",
                    subnetWebsite: "",
                    discord: "",
                    additional: ""
                ),
                taoReserve: 210_000_000_000_000,
                alphaReserve: 2_845_000_000_000_000,
                alphaOutstanding: 3_100_000_000_000_000,
                taoPerAlpha: taoPerAlpha,
                metadataStamp: stamp,
                pricesStamp: stamp
            )
        ])
    }
}
