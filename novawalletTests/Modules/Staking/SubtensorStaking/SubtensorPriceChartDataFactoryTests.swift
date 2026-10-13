@testable import novawallet
import XCTest

final class SubtensorPriceChartDataFactoryTests: XCTestCase {
    private typealias Helper = SubtensorPriceChartTestHelper

    func testDenseShortHistoryKeepsFlatZeroBoundaryEvenWithTinyBudgets() throws {
        let points: [SubtensorPricePoint] = (0 ..< 1000).map { (index: Int) in
            let date = Helper.end.addingTimeInterval(Double(index - 999) * 60)
            let value = Decimal(1000 - index)
            return SubtensorPricePoint(date: date, taoPerAlpha: value, fiatPerAlpha: value * 10)
        }
        let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
        let model = try Helper.chart(widget)
        let first = try XCTUnwrap(points.first)
        for budget in [0, 1, 2, 3, 10] {
            let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: model.series, availablePoints: budget))
            XCTAssertEqual(data.entries[0].coordinate, Helper.end.addingTimeInterval(-7 * Helper.day).timeIntervalSince1970)
            XCTAssertEqual(data.entries[0].value, 0)
            XCTAssertEqual(data.entries[1].coordinate, first.date.timeIntervalSince1970)
            XCTAssertEqual(data.entries[1].value, 0)
            XCTAssertNil(data.entries[1].sourceIndex)
            XCTAssertEqual(data.entries[2].coordinate, first.date.timeIntervalSince1970)
            XCTAssertEqual(data.entries[2].sourceIndex, 0)
            XCTAssertEqual(data.entries[2].value, 1000)
            XCTAssertEqual(data.entries.last?.sourceIndex, 999)
            for entry in data.entries where entry.sourceIndex != nil {
                let index = try XCTUnwrap(entry.sourceIndex)
                XCTAssertEqual(entry.coordinate, points[index].date.timeIntervalSince1970)
                XCTAssertEqual(entry.value, NSDecimalNumber(decimal: points[index].taoPerAlpha).doubleValue)
            }
            XCTAssertEqual(data.yRange.lowerBound, 0)
        }
    }

    func testMissingRegionsAreClassifiedBeforeNearestPointAndBoundariesAreReal() throws {
        let points = [Helper.point(daysBefore: 3, value: 3), Helper.point(daysBefore: 1, value: 2)]
        let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
        let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: Helper.chart(widget).series, availablePoints: 1))
        for days in [7.0, 5, 3 + 1 / Helper.day, 0.5, 0] {
            let date = Helper.end.addingTimeInterval(-days * Helper.day)
            XCTAssertEqual(data.selection(at: date.timeIntervalSince1970), .noData(date: date))
        }
        XCTAssertEqual(data.selection(at: points[0].date.timeIntervalSince1970), .point(sourceIndex: 0))
        XCTAssertEqual(data.selection(at: points[1].date.timeIntervalSince1970), .point(sourceIndex: 1))
        XCTAssertEqual(data.selection(at: data.xRange.lowerBound - 100), .noData(date: Date(timeIntervalSince1970: data.xRange.lowerBound)))
    }

    func testSelectionAfterReductionUsesTheOriginalSourceIndex() throws {
        let points = (0 ..< 101).map { index in Helper.point(daysBefore: Double(100 - index) / 100, value: Decimal(index + 1)) }
        let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
        let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: Helper.chart(widget).series, availablePoints: 4))
        XCTAssertEqual(data.entries.compactMap(\.sourceIndex), [0, 1, 51, 100])
        XCTAssertEqual(data.selection(at: points[51].date.timeIntervalSince1970), .point(sourceIndex: 51))
        XCTAssertEqual(data.selection(at: Helper.end.timeIntervalSince1970), .point(sourceIndex: 100))
    }

    func testPredecessorProvidesClippedCoverageButIsNeverSelected() throws {
        let points = [Helper.point(daysBefore: 8, value: 2), Helper.point(daysBefore: 6.99, value: 3), Helper.point(daysBefore: 0, value: 4)]
        let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
        let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: Helper.chart(widget).series, availablePoints: 1))
        XCTAssertEqual(data.entries.count, 3)
        XCTAssertEqual(data.entries.first?.coordinate, points[0].date.timeIntervalSince1970)
        XCTAssertNil(data.entries.first?.sourceIndex)
        XCTAssertEqual(data.entries.map(\.value), [2, 3, 4])
        XCTAssertEqual(data.selection(at: data.xRange.lowerBound), .point(sourceIndex: 1))
    }

    func testIndexedPortfolioCoordinatesSelectionAndExtremaArePreserved() throws {
        let values = (0 ..< 101).map(Double.init)
        let model = SubtensorPriceChartViewModel(values: values, axisLabels: ["100", "0"], isRising: true)
        let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: model.series, availablePoints: 4))
        XCTAssertEqual(data.entries.map(\.coordinate), [0, 1, 51, 100])
        XCTAssertEqual(data.entries.compactMap(\.sourceIndex), [0, 1, 51, 100])
        XCTAssertEqual(data.xRange, 0 ... 100)
        XCTAssertEqual(data.yRange, 0 ... 100)
        XCTAssertNil(data.coverage)
        XCTAssertEqual(data.selection(at: 51), .point(sourceIndex: 51))
        XCTAssertEqual(data.selection(at: -1), .point(sourceIndex: 0))
    }

    func testValidFlatSeriesHasFiniteBoundsAndNoArtificialPrefix() throws {
        let points = [Helper.point(daysBefore: 7, value: 3), Helper.point(daysBefore: 0, value: 3)]
        let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
        let data = try XCTUnwrap(SubtensorPriceChartDataFactory.create(series: Helper.chart(widget).series, availablePoints: 1))
        XCTAssertEqual(data.entries.count, 2)
        XCTAssertEqual(data.entries.map(\.value), [3, 3])
        XCTAssertLessThan(data.yRange.lowerBound, 3)
        XCTAssertGreaterThan(data.yRange.upperBound, 3)
    }
}
