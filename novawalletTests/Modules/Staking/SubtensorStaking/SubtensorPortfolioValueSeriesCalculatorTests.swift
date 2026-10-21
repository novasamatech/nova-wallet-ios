@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    private let hour: TimeInterval = 60 * 60

    func testWeeklyHistoryFillsHourlyGridCarriesValuesAndReplacesOpenBucketWithLiveTotal() throws {
        let history = try makeHistory(
            period: "SEVEN_DAYS",
            start: "2026-10-07T13:00:00Z",
            end: "2026-10-14T13:00:00Z",
            points: [
                ("2026-10-07T13:00:00Z", "12.5", "4875.25", true),
                ("2026-10-11T01:00:00Z", "13.1", "5240", true),
                ("2026-10-14T12:00:00Z", "13.4", "5400.2", false)
            ]
        )
        let now = try date("2026-10-14T12:00:00Z")

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: makePortfolio(pricedTaoValue: 13_600_000_000),
            histories: SubtensorPortfolioPriceHistories(period: .week, portfolio: history, taoFiat: nil),
            currentTaoPrice: 410,
            precision: 9,
            now: now
        )

        // 167 hourly instants before now (13:00 on 10-07 ... 11:00 on 10-14) plus the live point.
        XCTAssertEqual(series.points.count, 168)
        XCTAssertEqual(series.points[0], try point(at: "2026-10-07T13:00:00Z", taoValue: "12.5", fiatValue: "4875.25"))
        XCTAssertEqual(series.points[24], try point(at: "2026-10-08T13:00:00Z", taoValue: "12.5", fiatValue: "4875.25"))
        XCTAssertEqual(series.points[84], try point(at: "2026-10-11T01:00:00Z", taoValue: "13.1", fiatValue: "5240"))
        XCTAssertEqual(series.points[166], try point(at: "2026-10-14T11:00:00Z", taoValue: "13.1", fiatValue: "5240"))
        XCTAssertEqual(series.points[167], try point(at: "2026-10-14T12:00:00Z", taoValue: "13.6", fiatValue: "5480.8"))
        XCTAssertEqual(
            series.changeInFiat,
            try XCTUnwrap(Decimal(string: "605.55")) / XCTUnwrap(Decimal(string: "4875.25"))
        )
    }

    func testThirtyDayHistoryWithOnlyOpenBucketFillsWindowWithZerosThenLivePoint() throws {
        let history = try makeHistory(
            period: "THIRTY_DAYS",
            start: "2026-09-21T13:00:00Z",
            end: "2026-10-21T13:00:00Z",
            points: [("2026-10-21T12:00:00Z", "0", "0", false)]
        )
        let now = try date("2026-10-21T12:20:00Z")

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: makePortfolio(pricedTaoValue: 12_440_000_000),
            histories: SubtensorPortfolioPriceHistories(period: .month, portfolio: history, taoFiat: nil),
            currentTaoPrice: 273,
            precision: 9,
            now: now
        )

        // 180 four-hour instants before now (13:00 on 09-21 ... 09:00 on 10-21) plus the live point.
        XCTAssertEqual(series.points.count, 181)
        XCTAssertEqual(series.points.first, try point(at: "2026-09-21T13:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(series.points[179], try point(at: "2026-10-21T09:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertTrue(series.points.dropLast().allSatisfy { $0.taoValue == 0 && $0.fiatValue == 0 })
        XCTAssertEqual(series.points.last, try point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
        XCTAssertNil(series.changeInFiat)
    }

    func testOneDayHistoryWithSingleCompletedPointStartsAtZeroAndJumps() throws {
        let history = try makeHistory(
            period: "ONE_DAY",
            start: "2026-10-20T13:00:00Z",
            end: "2026-10-21T13:00:00Z",
            points: [
                ("2026-10-21T11:00:00Z", "12.44", "3397.51", true),
                ("2026-10-21T12:00:00Z", "0", "0", false)
            ]
        )
        let now = try date("2026-10-21T12:20:00Z")

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: makePortfolio(pricedTaoValue: 12_440_000_000),
            histories: SubtensorPortfolioPriceHistories(period: .day, portfolio: history, taoFiat: nil),
            currentTaoPrice: 273,
            precision: 9,
            now: now
        )

        // 22 zero hours (13:00 on 10-20 ... 10:00 on 10-21), the 11:00 point, the carried 12:00 point, live.
        XCTAssertEqual(series.points.count, 25)
        XCTAssertTrue(series.points.prefix(22).allSatisfy { $0.taoValue == 0 && $0.fiatValue == 0 })
        XCTAssertEqual(series.points[21], try point(at: "2026-10-21T10:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(series.points[22], try point(at: "2026-10-21T11:00:00Z", taoValue: "12.44", fiatValue: "3397.51"))
        XCTAssertEqual(series.points[23], try point(at: "2026-10-21T12:00:00Z", taoValue: "12.44", fiatValue: "3397.51"))
        XCTAssertEqual(series.points[24], try point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
        XCTAssertNil(series.changeInFiat)
    }

    func testEmptyNinetyDayHistoryFillsWindowWithZerosThenLivePoint() throws {
        let history = try makeHistory(
            period: "NINETY_DAYS",
            start: "2026-07-23T13:00:00Z",
            end: "2026-10-21T13:00:00Z",
            points: []
        )
        let now = try date("2026-10-21T12:20:00Z")

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: makePortfolio(pricedTaoValue: 12_440_000_000),
            histories: SubtensorPortfolioPriceHistories(period: .quarter, portfolio: history, taoFiat: nil),
            currentTaoPrice: 273,
            precision: 9,
            now: now
        )

        // 270 eight-hour instants before now (13:00 on 07-23 ... 05:00 on 10-21) plus the live point.
        XCTAssertEqual(series.points.count, 271)
        XCTAssertTrue(series.points.dropLast().allSatisfy { $0.taoValue == 0 && $0.fiatValue == 0 })
        XCTAssertEqual(series.points[269], try point(at: "2026-10-21T05:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(series.points.last, try point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
        XCTAssertNil(series.changeInFiat)
    }

    func testCarriedPointRepricesTaoWithFiatHistoryWhenAvailable() throws {
        let history = try makeHistory(
            period: "ONE_DAY",
            start: "2026-10-20T13:00:00Z",
            end: "2026-10-21T13:00:00Z",
            points: [("2026-10-20T13:00:00Z", "10", "2700", true)]
        )
        let start = try date("2026-10-20T13:00:00Z")
        let taoFiat = PriceHistory(
            currencyId: Currency.usd.id,
            items: (0 ..< 24).map { index in
                PriceHistoryItem(
                    startedAt: UInt64(start.timeIntervalSince1970 + TimeInterval(index) * hour),
                    value: Decimal(270 + index)
                )
            }
        )
        let now = try date("2026-10-20T16:30:00Z")

        let series = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: makePortfolio(pricedTaoValue: 10_000_000_000),
            histories: SubtensorPortfolioPriceHistories(period: .day, portfolio: history, taoFiat: taoFiat),
            currentTaoPrice: 280,
            precision: 9,
            now: now
        )

        // 13:00 real point, 14:00 15:00 16:00 carried at the hourly TAO price, then live at 280.
        XCTAssertEqual(series.points.count, 5)
        XCTAssertEqual(series.points[0], try point(at: "2026-10-20T13:00:00Z", taoValue: "10", fiatValue: "2700"))
        XCTAssertEqual(series.points[1], try point(at: "2026-10-20T14:00:00Z", taoValue: "10", fiatValue: "2710"))
        XCTAssertEqual(series.points[3], try point(at: "2026-10-20T16:00:00Z", taoValue: "10", fiatValue: "2730"))
        XCTAssertEqual(series.points[4], try point(at: "2026-10-20T16:30:00Z", taoValue: "10", fiatValue: "2800"))
        XCTAssertEqual(series.changeInFiat, try XCTUnwrap(Decimal(string: "100")) / 2700)
    }

    func testAllTimeHistoryKeepsEveryRegisteredPointAndItsChange() {
        let points = [1_700_000_000, 1_760_000_000, 1_790_000_000].enumerated().map { index, time in
            SubtensorPricePoint(
                date: Date(timeIntervalSince1970: TimeInterval(time)),
                taoPerAlpha: Decimal(index + 1),
                fiatPerAlpha: Decimal(300 * (index + 1))
            )
        }

        let history = SubtensorPriceHistoryOperationFactory.makeHistory(
            subnet: SubtensorSubnetRef(netuid: 3, registeredAt: 0),
            period: .all,
            points: points,
            registrationDate: Date(timeIntervalSince1970: 1_750_000_000)
        )

        XCTAssertEqual(history.points, Array(points.dropFirst()))
        XCTAssertEqual(history.changeInTao, Decimal(string: "0.5"))
    }

    // MARK: - Fixtures

    private func makePortfolio(pricedTaoValue: Balance) -> SubtensorPortfolio {
        SubtensorPortfolio(root: nil, subnets: [], pricedTaoValue: pricedTaoValue, unpricedNetuids: [])
    }

    private func makeHistory(
        period: String,
        start: String,
        end: String,
        points: [(timestamp: String, tao: String, usd: String, completed: Bool)]
    ) throws -> BittensorApi.PortfolioHistoryCollection {
        let encodedPoints = points.map { point in
            """
            {"timestamp": "\(point.timestamp)", "reportedValueTao": "\(point.tao)",
             "reportedValueUsd": "\(point.usd)", "completed": \(point.completed)}
            """
        }.joined(separator: ",")

        let json = """
        {
          "period": "\(period)",
          "window": {"start": "\(start)", "end": "\(end)"},
          "points": [\(encodedPoints)],
          "historyScope": "TAO_APP_PARTIAL",
          "meta": {
            "completeness": "COMPLETE",
            "components": {
              "portfolioHistory": {
                "asOf": "\(end)",
                "freshness": "FRESH",
                "availability": "AVAILABLE",
                "valueQuality": "DERIVED",
                "sourceClass": "PRIMARY"
              }
            }
          }
        }
        """

        return try JSONDecoder().decode(BittensorApi.PortfolioHistoryCollection.self, from: Data(json.utf8))
    }

    private func date(_ iso: String) throws -> Date {
        try XCTUnwrap(BittensorApi.instant(from: iso))
    }

    private func point(at iso: String, taoValue: String, fiatValue: String) throws -> SubtensorPortfolioValuePoint {
        try SubtensorPortfolioValuePoint(
            date: date(iso),
            taoValue: XCTUnwrap(Decimal(string: taoValue)),
            fiatValue: XCTUnwrap(Decimal(string: fiatValue))
        )
    }
}
