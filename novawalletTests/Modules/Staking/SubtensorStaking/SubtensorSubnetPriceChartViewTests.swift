import DGCharts
@testable import novawallet
import XCTest

@MainActor
final class SubtensorSubnetPriceChartViewTests: XCTestCase {
    private typealias Helper = SubtensorPriceChartTestHelper

    func testActualAxisEntriesAndProductionTouchRouteRespectTheMissingPrefix() throws {
        let model = try Helper.chart(Helper.factory().createWidget(for: Helper.params(), locale: Helper.locale))
        let view = SubtensorSubnetPriceChartView(isSelectable: true)
        let delegate = SelectionSpy()
        view.delegate = delegate
        view.frame = CGRect(x: 0, y: 0, width: 375, height: 208)
        view.bind(viewModel: model)
        view.layoutIfNeeded()
        let chart = try XCTUnwrap(view.subviews.compactMap { $0 as? LineChartView }.first)
        let start = Helper.end.addingTimeInterval(-7 * Helper.day).timeIntervalSince1970
        let first = Helper.end.addingTimeInterval(-3 * Helper.day).timeIntervalSince1970
        XCTAssertEqual(chart.xAxis.axisMinimum, start)
        XCTAssertEqual(chart.xAxis.axisMaximum, Helper.end.timeIntervalSince1970)
        XCTAssertFalse(chart.highlightPerDragEnabled)
        let dataSet = try XCTUnwrap(chart.lineData?.dataSets.first)
        XCTAssertEqual(dataSet.entryForIndex(0)?.y, 0)
        XCTAssertEqual(dataSet.entryForIndex(1)?.x, first)
        XCTAssertEqual(dataSet.entryForIndex(1)?.y, 0)
        XCTAssertEqual(dataSet.entryForIndex(2)?.x, first)
        XCTAssertEqual(dataSet.entryForIndex(2)?.y, 3)
        let pixel = chart.getTransformer(forAxis: .right).pixelForValues(x: start + Helper.day, y: 0)
        view.highlightEntry(at: pixel)
        guard case let .noData(date) = delegate.selections.last else { return XCTFail("Expected no data") }
        XCTAssertEqual(date.timeIntervalSince1970, start + Helper.day, accuracy: 0.0001)
        XCTAssertFalse(chart.valuesToHighlight())
        let entry = try XCTUnwrap(dataSet.entryForIndex(2))
        view.chartValueSelected(chart, entry: entry, highlight: Highlight(x: first, y: 3, dataSetIndex: 0))
        XCTAssertEqual(delegate.selections.count, 1)
        XCTAssertFalse(chart.valuesToHighlight())
        view.highlightEntry(at: chart.getTransformer(forAxis: .right).pixelForValues(x: first, y: 3))
        XCTAssertEqual(delegate.selections.last, .point(sourceIndex: 0))
        XCTAssertEqual(chart.highlighted.first?.y, 3)
        view.endSelection()
        view.endSelection()
        XCTAssertEqual(delegate.endCount, 1)
    }

    func testBlankTailAndRebindClearNoDataSelectionOnceAndResetIndexBounds() throws {
        let history = Helper.history(points: [Helper.point(daysBefore: 3, value: 3), Helper.point(daysBefore: 1, value: 2)])
        let model = try Helper.chart(Helper.factory().createWidget(for: Helper.params(history: history), locale: Helper.locale))
        let view = SubtensorSubnetPriceChartView(isSelectable: true)
        let delegate = SelectionSpy()
        view.delegate = delegate
        view.frame = CGRect(x: 0, y: 0, width: 375, height: 208)
        view.bind(viewModel: model)
        view.layoutIfNeeded()
        let chart = try XCTUnwrap(view.subviews.compactMap { $0 as? LineChartView }.first)
        let tail = Helper.end.addingTimeInterval(-Helper.day / 2).timeIntervalSince1970
        view.highlightEntry(at: chart.getTransformer(forAxis: .right).pixelForValues(x: tail, y: 0))
        guard case let .noData(date) = delegate.selections.last else { return XCTFail("Expected blank tail") }
        XCTAssertEqual(date.timeIntervalSince1970, tail, accuracy: 0.0001)
        view.bind(viewModel: SubtensorPriceChartViewModel(values: [2, 3, 4], axisLabels: ["4", "2"], isRising: true))
        view.layoutIfNeeded()
        XCTAssertEqual(delegate.endCount, 1)
        XCTAssertEqual(chart.xAxis.axisMinimum, 0)
        XCTAssertEqual(chart.xAxis.axisMaximum, 2)
        XCTAssertTrue(chart.highlightPerDragEnabled)
        view.highlightEntry(at: chart.getTransformer(forAxis: .right).pixelForValues(x: 2, y: 4))
        XCTAssertEqual(delegate.selections.last, .point(sourceIndex: 2))
        view.frame.size.width = 300
        view.layoutIfNeeded()
        XCTAssertEqual(delegate.endCount, 2)
    }

    private final class SelectionSpy: SubtensorPriceChartViewDelegate {
        var selections: [SubtensorPriceChartSelection] = []
        var endCount = 0
        func priceChartViewDidBeginSelection(_: SubtensorSubnetPriceChartView) {}
        func priceChartView(_: SubtensorSubnetPriceChartView, didSelect selection: SubtensorPriceChartSelection) {
            selections.append(selection)
        }

        func priceChartViewDidEndSelection(_: SubtensorSubnetPriceChartView) { endCount += 1 }
    }
}
