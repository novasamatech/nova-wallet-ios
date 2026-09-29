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

    private func group(netuid: UInt16, alpha: Balance, taoValue: Balance?) -> SubtensorPortfolioGroup {
        SubtensorPortfolioGroup(
            netuid: netuid,
            positions: [],
            totalAlpha: alpha,
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
