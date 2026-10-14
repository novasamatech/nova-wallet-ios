@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    func testUsdHistoryMapsCompletedPointsAndReplacesOpenBucketWithLiveTotal() throws {
        let history = try JSONDecoder().decode(
            BittensorApi.PortfolioHistoryCollection.self,
            from: Data(weeklyHistoryJson.utf8)
        )
        let portfolio = SubtensorPortfolio(
            root: nil,
            subnets: [],
            pricedTaoValue: 13_600_000_000,
            unpricedNetuids: []
        )

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: SubtensorPortfolioPriceHistories(period: .week, portfolio: history, taoFiat: nil),
            currentTaoPrice: 410,
            precision: 9,
            now: Date(timeIntervalSince1970: 1_791_980_400)
        )

        let expected = try SubtensorPortfolioValueSeries(
            points: [
                point(at: 1_791_378_000, taoValue: "12.5", fiatValue: "4875.25"),
                point(at: 1_791_680_400, taoValue: "13.1", fiatValue: "5240"),
                point(at: 1_791_980_400, taoValue: "13.6", fiatValue: "5576")
            ],
            changeInFiat: XCTUnwrap(Decimal(string: "700.75")) / XCTUnwrap(Decimal(string: "4875.25"))
        )
        XCTAssertEqual(series, expected)
    }

    private let weeklyHistoryJson = """
    {
      "period": "SEVEN_DAYS",
      "window": {"start": "2026-10-07T13:00:00Z", "end": "2026-10-14T13:00:00Z"},
      "points": [
        {"timestamp": "2026-10-07T13:00:00Z", "reportedValueTao": "12.5",
         "reportedValueUsd": "4875.25", "completed": true},
        {"timestamp": "2026-10-11T01:00:00Z", "reportedValueTao": "13.1",
         "reportedValueUsd": "5240", "completed": true},
        {"timestamp": "2026-10-14T12:00:00Z", "reportedValueTao": "13.4",
         "reportedValueUsd": "5400.2", "completed": false}
      ],
      "historyScope": "TAO_APP_PARTIAL",
      "meta": {
        "completeness": "COMPLETE",
        "components": {
          "portfolioHistory": {
            "asOf": "2026-10-14T12:05:00Z",
            "freshness": "FRESH",
            "availability": "AVAILABLE",
            "valueQuality": "DERIVED",
            "sourceClass": "PRIMARY"
          }
        }
      }
    }
    """

    private func point(at time: TimeInterval, taoValue: String, fiatValue: String) throws -> SubtensorPortfolioValuePoint {
        try SubtensorPortfolioValuePoint(
            date: Date(timeIntervalSince1970: time),
            taoValue: XCTUnwrap(Decimal(string: taoValue)),
            fiatValue: XCTUnwrap(Decimal(string: fiatValue))
        )
    }
}
