@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    func testSeriesAnchorsSubnetsToTheirChainSpotAndEndsAtTheHeaderTotal() throws {
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0, alpha: 10_000_000_000, taoValue: 10_000_000_000),
            subnets: [
                group(netuid: 64, alpha: 100_000_000_000, taoValue: 7_000_000_000),
                group(netuid: 19, alpha: 60_000_000_000, taoValue: 3_000_000_000),
                group(netuid: 7, alpha: 30_000_000_000, taoValue: nil)
            ],
            pricedTaoValue: 20_000_000_000,
            unpricedNetuids: [7]
        )

        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(
                currencyId: Currency.usd.id,
                items: [
                    PriceHistoryItem(startedAt: 0, value: 400),
                    PriceHistoryItem(startedAt: 302_400, value: 410),
                    PriceHistoryItem(startedAt: 604_800, value: 420)
                ]
            ),
            subnets: [
                history(netuid: 64, [(0, "0.05"), (302_400, "0.06"), (604_800, "0.08")]),
                history(netuid: 19, [(0, "0.05"), (302_400, "0.05"), (604_800, "0.05")]),
                history(netuid: 7, [(0, "0.5"), (302_400, "0.5"), (604_800, "0.5")])
            ]
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: 417,
            precision: 9
        )

        let expected = try SubtensorPortfolioValueSeries(
            points: [
                point(at: 0, taoValue: "17.375", fiatValue: "6950"),
                point(at: 302_400, taoValue: "18.25", fiatValue: "7482.5"),
                point(at: 604_800, taoValue: "20", fiatValue: "8340")
            ],
            changeInFiat: XCTUnwrap(Decimal(string: "0.2"))
        )

        XCTAssertEqual(series, expected)
    }

    func testSubnetWhoseHistoryStopsBeforeTheGridEndLeavesTheSeriesEmpty() throws {
        let portfolio = SubtensorPortfolio(
            root: nil,
            subnets: [
                group(netuid: 64, alpha: 100_000_000_000, taoValue: 8_000_000_000),
                group(netuid: 108, alpha: 5_000_000_000, taoValue: 2_000_000_000)
            ],
            pricedTaoValue: 10_000_000_000,
            unpricedNetuids: []
        )

        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(
                currencyId: Currency.usd.id,
                items: [
                    PriceHistoryItem(startedAt: 0, value: 400),
                    PriceHistoryItem(startedAt: 302_400, value: 410),
                    PriceHistoryItem(startedAt: 453_600, value: 415),
                    PriceHistoryItem(startedAt: 604_800, value: 420)
                ]
            ),
            subnets: [
                history(netuid: 64, [(0, "0.05"), (302_400, "0.06"), (453_600, "0.07"), (604_800, "0.08")]),
                history(netuid: 108, [(0, "0.5"), (302_400, "0.4")])
            ]
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: 420,
            precision: 9
        )

        XCTAssertEqual(series, SubtensorPortfolioValueSeries(points: [], changeInFiat: nil))
    }

    func testConfirmedUnlistedHoldingContributesItsCurrentTaoValueToMixedPortfolio() throws {
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0, alpha: 10_000_000_000, taoValue: 10_000_000_000),
            subnets: [
                group(netuid: 64, alpha: 100_000_000_000, taoValue: 7_000_000_000),
                group(netuid: 19, alpha: 60_000_000_000, taoValue: 3_000_000_000)
            ],
            pricedTaoValue: 20_000_000_000,
            unpricedNetuids: []
        )
        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: weeklyTaoHistory(),
            subnets: [history(netuid: 64, [(0, "0.05"), (302_400, "0.06"), (604_800, "0.08")])],
            notListedNetuids: [19]
        )

        let series = calculate(portfolio, histories)

        let expected = try [
            point(at: 0, taoValue: "17.375", fiatValue: "6950"),
            point(at: 302_400, taoValue: "18.25", fiatValue: "7482.5"),
            point(at: 604_800, taoValue: "20", fiatValue: "8340")
        ]
        XCTAssertEqual(series.points, expected)
        XCTAssertEqual(series.changeInFiat, Decimal(string: "0.2"))
    }

    func testAllUnlistedPortfolioUsesTaoHistoryForEveryPortfolioPeriod() {
        let durations: [(SubtensorPricePeriod, UInt64)] = [
            (.day, 86400), (.week, 604_800), (.month, 2_592_000), (.year, 31_536_000), (.all, 63_072_000)
        ]

        for (period, duration) in durations {
            let histories = SubtensorPortfolioPriceHistories(
                period: period,
                taoFiat: PriceHistory(currencyId: Currency.usd.id, items: [
                    PriceHistoryItem(startedAt: 0, value: 400),
                    PriceHistoryItem(startedAt: duration / 2, value: 410),
                    PriceHistoryItem(startedAt: duration, value: 420)
                ]),
                subnets: [],
                notListedNetuids: [19]
            )

            let series = calculate(unlistedPortfolio(), histories)

            XCTAssertEqual(series.points.map(\.taoValue), [3, 3, 3], "\(period)")
            XCTAssertEqual(series.points.map(\.fiatValue), [1200, 1230, 1251], "\(period)")
            XCTAssertEqual(series.points.map(\.date.timeIntervalSince1970), [0, Double(duration / 2), Double(duration)])
            XCTAssertEqual(series.changeInFiat, Decimal(string: "0.0425"))
        }
    }

    func testOverlappingStatusAndRedundantHistoryDoNotDoubleCountUnlistedHolding() throws {
        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: weeklyTaoHistory(),
            subnets: [history(netuid: 19, [(0, "0.01"), (302_400, "0.02"), (604_800, "0.03")])],
            notListedNetuids: [19, 100],
            failedNetuids: [19, 101]
        )

        XCTAssertEqual(calculate(unlistedPortfolio(), histories).points.map(\.taoValue), [3, 3, 3])
    }

    func testFailedHistoryRetainsExistingFlatCurrentValueFallback() {
        let histories = SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: weeklyTaoHistory(),
            subnets: [],
            failedNetuids: [19]
        )

        XCTAssertEqual(calculate(unlistedPortfolio(), histories).points.map(\.fiatValue), [1200, 1230, 1251])
    }

    func testUnlistedHoldingDoesNotHideMissingOrUnusableListedHistory() throws {
        let portfolio = SubtensorPortfolio(
            root: nil,
            subnets: [
                group(netuid: 19, alpha: 60_000_000_000, taoValue: 3_000_000_000),
                group(netuid: 64, alpha: 100_000_000_000, taoValue: 7_000_000_000)
            ],
            pricedTaoValue: 10_000_000_000,
            unpricedNetuids: []
        )
        let wrongPeriod = try history(netuid: 64, [(0, "0.05"), (604_800, "0.08")], period: .month)
        let invalid = SubtensorPriceHistory(
            subnet: SubtensorSubnetRef(netuid: 64, registeredAt: 1),
            period: .week,
            points: [0, 604_800].map {
                SubtensorPricePoint(date: Date(timeIntervalSince1970: $0), taoPerAlpha: .nan, fiatPerAlpha: 1)
            },
            changeInTao: nil,
            changeInFiat: nil
        )
        let unusable: [[SubtensorPriceHistory]] = try [
            [], [history(netuid: 64, [])], [wrongPeriod], [invalid],
            [history(netuid: 64, [(0, "0.05"), (302_400, "0.06")])]
        ]

        for subnets in unusable {
            let histories = SubtensorPortfolioPriceHistories(
                period: .week,
                taoFiat: weeklyTaoHistory(),
                subnets: subnets,
                notListedNetuids: [19]
            )
            XCTAssertEqual(calculate(portfolio, histories), SubtensorPortfolioValueSeries(points: [], changeInFiat: nil))
        }
    }

    func testUnlistedHoldingStillRequiresUsableTaoHistory() {
        for values in [[], [0, -1, Decimal.nan]] {
            let histories = SubtensorPortfolioPriceHistories(
                period: .week,
                taoFiat: PriceHistory(currencyId: Currency.usd.id, items: values.enumerated().map {
                    PriceHistoryItem(startedAt: UInt64($0.offset) * 302_400, value: $0.element)
                }),
                subnets: [],
                notListedNetuids: [19]
            )
            XCTAssertEqual(calculate(unlistedPortfolio(), histories), SubtensorPortfolioValueSeries(points: [], changeInFiat: nil))
        }
    }

    func testInvalidCurrentPriceOrOverflowingLatestValueCannotLeaveAnOlderCurve() {
        let histories = SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: weeklyTaoHistory(),
            subnets: [],
            notListedNetuids: [19]
        )

        for price in [Decimal.nan, 0, -1, Decimal.greatestFiniteMagnitude] {
            let series = calculate(unlistedPortfolio(), histories, price: price)
            XCTAssertEqual(series, SubtensorPortfolioValueSeries(points: [], changeInFiat: nil))
        }
    }

    private func weeklyTaoHistory() -> PriceHistory {
        PriceHistory(currencyId: Currency.usd.id, items: [
            PriceHistoryItem(startedAt: 0, value: 400),
            PriceHistoryItem(startedAt: 302_400, value: 410),
            PriceHistoryItem(startedAt: 604_800, value: 420)
        ])
    }

    private func unlistedPortfolio() -> SubtensorPortfolio {
        SubtensorPortfolio(
            root: nil,
            subnets: [group(netuid: 19, alpha: 60_000_000_000, taoValue: 3_000_000_000)],
            pricedTaoValue: 3_000_000_000,
            unpricedNetuids: []
        )
    }

    private func calculate(
        _ portfolio: SubtensorPortfolio,
        _ histories: SubtensorPortfolioPriceHistories,
        price: Decimal = 417
    ) -> SubtensorPortfolioValueSeries {
        SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: price,
            precision: 9
        )
    }

    private func group(netuid: UInt16, alpha: Balance, taoValue: Balance?) -> SubtensorPortfolioGroup {
        SubtensorPortfolioGroup(
            netuid: netuid,
            positions: [],
            totalAlpha: alpha,
            redeemable: 0,
            taoValue: taoValue,
            availability: nil,
            primaryHotkey: Data(repeating: 0x0A, count: 32)
        )
    }

    private func point(at time: TimeInterval, taoValue: String, fiatValue: String) throws -> SubtensorPortfolioValuePoint {
        try SubtensorPortfolioValuePoint(
            date: Date(timeIntervalSince1970: time),
            taoValue: XCTUnwrap(Decimal(string: taoValue)),
            fiatValue: XCTUnwrap(Decimal(string: fiatValue))
        )
    }

    private func history(
        netuid: UInt16,
        _ points: [(TimeInterval, String)],
        period: SubtensorPricePeriod = .week
    ) throws -> SubtensorPriceHistory {
        try SubtensorPriceHistory(
            subnet: SubtensorSubnetRef(netuid: netuid, registeredAt: 1),
            period: period,
            points: points.map { time, taoPerAlpha in
                try SubtensorPricePoint(
                    date: Date(timeIntervalSince1970: time),
                    taoPerAlpha: XCTUnwrap(Decimal(string: taoPerAlpha)),
                    fiatPerAlpha: 0
                )
            },
            changeInTao: nil,
            changeInFiat: nil
        )
    }
}
