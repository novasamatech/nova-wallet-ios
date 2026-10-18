@testable import novawallet
import XCTest

final class SubtensorPriceChartDataTests: XCTestCase {
    private let end = Date(timeIntervalSince1970: 1_790_000_000)

    func testTouchPastLastSampleSelectsLastPoint() throws {
        let data = try XCTUnwrap(makeData())

        XCTAssertEqual(data.selection(at: data.xRange.upperBound), .point(sourceIndex: 2))
        XCTAssertEqual(data.selection(at: data.xRange.upperBound + 3600), .point(sourceIndex: 2))
    }

    func testTouchBeforeFirstSampleSelectsNoData() throws {
        let data = try XCTUnwrap(makeData())
        let start = data.xRange.lowerBound

        XCTAssertEqual(data.selection(at: start), .noData(date: Date(timeIntervalSince1970: start)))
    }

    private func makeData() -> SubtensorPriceChartData? {
        let points = [6 * 86400, 3 * 86400, 1800].enumerated().map { index, age in
            SubtensorPriceChartViewModel.Point(
                sourceIndex: index,
                date: end.addingTimeInterval(-TimeInterval(age)),
                value: Decimal(index + 1)
            )
        }

        let series = SubtensorPriceChartViewModel.DatedSeries(
            points: points,
            range: end.addingTimeInterval(-7 * 86400) ... end,
            predecessor: nil,
            coverageTolerance: SubtensorPricePeriod.week.coverageTolerance
        )

        return SubtensorPriceChartDataFactory.create(series: .dated(series), availablePoints: 0)
    }
}
