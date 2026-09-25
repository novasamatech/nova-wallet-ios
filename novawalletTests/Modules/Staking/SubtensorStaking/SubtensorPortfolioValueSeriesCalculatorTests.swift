@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    func testSeriesValuesRootFlatAndEachSubnetAtItsTaoSeriesTimesTaoFiat() throws {
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0, alpha: 10_000_000_000),
            subnets: [
                group(netuid: 64, alpha: 100_000_000_000),
                group(netuid: 19, alpha: 50_000_000_000),
                group(netuid: 7, alpha: 30_000_000_000),
                group(netuid: 12, alpha: 0)
            ],
            pricedTaoValue: 0,
            unpricedNetuids: []
        )

        let histories = try [
            history(netuid: 64, [(60, "0.05"), (604_860, "0.06"), (608_460, "0.07")]),
            history(netuid: 19, [(0, "0.02"), (604_200, "0.02")])
        ]

        let taoFiat = PriceHistory(
            currencyId: Currency.usd.id,
            items: [
                PriceHistoryItem(startedAt: 0, value: 400),
                PriceHistoryItem(startedAt: 604_800, value: 410),
                PriceHistoryItem(startedAt: 608_400, value: 420)
            ]
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            taoFiatHistory: taoFiat,
            period: .week,
            precision: 9
        )

        let expected = try SubtensorPortfolioValueSeries(
            points: [
                SubtensorPortfolioValuePoint(date: Date(timeIntervalSince1970: 0), taoValue: 16, fiatValue: 6400),
                SubtensorPortfolioValuePoint(date: Date(timeIntervalSince1970: 604_800), taoValue: 17, fiatValue: 6970)
            ],
            changeInTao: XCTUnwrap(Decimal(string: "0.0625")),
            changeInFiat: XCTUnwrap(Decimal(string: "0.0890625")),
            netuidsWithoutHistory: [7]
        )

        XCTAssertEqual(series, expected)
    }

    private func group(netuid: UInt16, alpha: Balance) -> SubtensorPortfolioGroup {
        SubtensorPortfolioGroup(
            netuid: netuid,
            positions: [],
            totalAlpha: alpha,
            taoValue: nil,
            availability: nil,
            primaryHotkey: Data(repeating: 0x0A, count: 32)
        )
    }

    private func history(netuid: UInt16, _ points: [(TimeInterval, String)]) throws -> SubtensorPriceHistory {
        try SubtensorPriceHistory(
            subnet: SubtensorSubnetRef(netuid: netuid, registeredAt: 1),
            period: .week,
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
