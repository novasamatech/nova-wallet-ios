@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    func testSettledPointsArePricedByTheTaoGridAndTheOpenBucketIsReplacedByLiveState() throws {
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0, alpha: 10_000_000_000, taoValue: 10_000_000_000),
            subnets: [group(netuid: 64, alpha: 100_000_000_000, taoValue: 12_000_000_000)],
            pricedTaoValue: 22_000_000_000,
            unpricedNetuids: []
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
            stake: stakeHistory(
                period: .week,
                start: 0,
                end: 608_400,
                points: [(0, "17.5", true), (302_400, "18.25", true), (604_800, "21", false)]
            )
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: 417,
            precision: 9,
            now: Date(timeIntervalSince1970: 606_000)
        )

        let expected = try SubtensorPortfolioValueSeries(
            points: [
                point(at: 0, taoValue: "17.5", fiatValue: "7000"),
                point(at: 302_400, taoValue: "18.25", fiatValue: "7482.5"),
                point(at: 606_000, taoValue: "22", fiatValue: "9174")
            ],
            changeInFiat: Decimal(2174) / Decimal(7000)
        )

        XCTAssertEqual(series, expected)
    }

    func testPartiallyPricedPortfolioKeepsTheOpenBucketAndSkipsPointsWithoutTaoPrice() throws {
        let portfolio = SubtensorPortfolio(
            root: nil,
            subnets: [
                group(netuid: 64, alpha: 100_000_000_000, taoValue: 8_000_000_000),
                group(netuid: 7, alpha: 30_000_000_000, taoValue: nil)
            ],
            pricedTaoValue: 8_000_000_000,
            unpricedNetuids: [7]
        )

        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(
                currencyId: Currency.usd.id,
                items: [
                    PriceHistoryItem(startedAt: 0, value: 400),
                    PriceHistoryItem(startedAt: 302_400, value: 410)
                ]
            ),
            stake: stakeHistory(
                period: .week,
                start: 0,
                end: 306_000,
                points: [(0, "10", true), (151_200, "11", true), (302_400, "12", false)]
            )
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: 420,
            precision: 9,
            now: Date(timeIntervalSince1970: 303_000)
        )

        let expected = try SubtensorPortfolioValueSeries(
            points: [
                point(at: 0, taoValue: "10", fiatValue: "4000"),
                point(at: 302_400, taoValue: "12", fiatValue: "4920")
            ],
            changeInFiat: XCTUnwrap(Decimal(string: "0.23"))
        )

        XCTAssertEqual(series, expected)
    }

    func testChangeIsHiddenWhenTheHistoryStartsAfterTheWindow() throws {
        let portfolio = SubtensorPortfolio(
            root: group(netuid: 0, alpha: 5_000_000_000, taoValue: 5_000_000_000),
            subnets: [],
            pricedTaoValue: 5_000_000_000,
            unpricedNetuids: []
        )

        let histories = try SubtensorPortfolioPriceHistories(
            period: .week,
            taoFiat: PriceHistory(
                currencyId: Currency.usd.id,
                items: [
                    PriceHistoryItem(startedAt: 100_800, value: 400),
                    PriceHistoryItem(startedAt: 604_800, value: 420)
                ]
            ),
            stake: stakeHistory(
                period: .week,
                start: 0,
                end: 608_400,
                points: [(100_800, "4", true), (604_800, "5", false)]
            )
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: histories,
            currentTaoPrice: 420,
            precision: 9,
            now: Date(timeIntervalSince1970: 606_000)
        )

        XCTAssertEqual(series.points.map(\.taoValue), [4, 5])
        XCTAssertNil(series.changeInFiat)
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

    private func stakeHistory(
        period: SubtensorPricePeriod,
        start: TimeInterval,
        end: TimeInterval,
        points: [(TimeInterval, String, Bool)]
    ) throws -> SubtensorPortfolioStakeHistory {
        try SubtensorPortfolioStakeHistory(
            period: period,
            windowStart: Date(timeIntervalSince1970: start),
            windowEnd: Date(timeIntervalSince1970: end),
            points: points.map { time, taoValue, isCompleted in
                try SubtensorPortfolioStakePoint(
                    date: Date(timeIntervalSince1970: time),
                    taoValue: XCTUnwrap(Decimal(string: taoValue)),
                    usdValue: 0,
                    isCompleted: isCompleted
                )
            }
        )
    }
}
