import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorPriceWidgetViewModelFactoryTests: XCTestCase {
    private typealias Helper = SubtensorPriceChartTestHelper

    func testShortHistoryRetainsDatesValuesAndUnevenSpacingInBothDenominations() throws {
        let history = Helper.history()
        let cases: [(SubtensorPricePeriod, Double, [Double])] = [
            (SubtensorPricePeriod.week, 7.0, [4.0 / 7, 6.0 / 7, 1]),
            (.month, 30.0, [27.0 / 30, 29.0 / 30, 1])
        ]
        for (period, duration, expected) in cases {
            for isFiat in [false, true] {
                let params = Helper.params(history: history, period: period, isFiat: isFiat)
                let widget = Helper.factory().createWidget(for: params, locale: Helper.locale)
                let series = try Helper.series(Helper.chart(widget))
                XCTAssertEqual(series.range, Helper.end.addingTimeInterval(-duration * Helper.day) ... Helper.end)
                XCTAssertEqual(series.points.map(\.date), history.points.map(\.date))
                XCTAssertEqual(series.points.map(\.value), isFiat ? [30, 20, 10] : [3, 2, 1])
                XCTAssertEqual(series.points.map(\.sourceIndex), [0, 1, 2])
                for (point, fraction) in zip(series.points, expected) {
                    XCTAssertEqual(point.date.timeIntervalSince(series.range.lowerBound) / (duration * Helper.day), fraction, accuracy: 1e-12)
                }
                XCTAssertEqual(widget.header.change, .hidden)
                XCTAssertFalse(try Helper.chart(widget).isRising)
            }
        }
    }

    func testAllExposedPeriodsUseTheUTCPolicyAndAllUsesTheEarliestSample() throws {
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        defer { NSTimeZone.default = originalTimeZone }
        let end = Date(timeIntervalSince1970: 1_780_228_800) // May 31, 2026 at noon UTC
        let starts: [(SubtensorPricePeriod, Date)] = [
            (.day, end.addingTimeInterval(-Helper.day)),
            (.week, end.addingTimeInterval(-7 * Helper.day)),
            (.month, end.addingTimeInterval(-30 * Helper.day)),
            (.quarter, Date(timeIntervalSince1970: 1_772_280_000)), // February 28
            (.year, end.addingTimeInterval(-365 * Helper.day)),
            (.all, end.addingTimeInterval(-800 * Helper.day))
        ]
        for (period, start) in starts {
            let history = Helper.history(points: [
                SubtensorPricePoint(date: start, taoPerAlpha: 1, fiatPerAlpha: 10),
                SubtensorPricePoint(date: end, taoPerAlpha: 2, fiatPerAlpha: 20)
            ], period: period)
            let widget = Helper.factory().createWidget(for: Helper.params(history: history, period: period, end: end), locale: Helper.locale)
            let series = try Helper.series(Helper.chart(widget))
            XCTAssertEqual(series.range, start ... end)
            XCTAssertFalse(series.hasMissingPrefix)
        }
    }

    func testRealAndNoDataSelectionsShowActualDatesWithoutPartialPeriodReturns() {
        let history = Helper.history()
        for isFiat in [false, true] {
            for (index, point) in history.points.enumerated() {
                let params = Helper.params(history: history, isFiat: isFiat, selection: .point(sourceIndex: index))
                let header = Helper.factory().createHeader(for: params, locale: Helper.locale)
                XCTAssertEqual(header.change, .date(dateText(point.date)))
                XCTAssertFalse(header.price.contains("999"))
            }
        }
        let date = Helper.end.addingTimeInterval(-6 * Helper.day)
        let header = Helper.factory().createHeader(for: Helper.params(selection: .noData(date: date)), locale: Helper.locale)
        XCTAssertEqual(header.price, "—")
        XCTAssertEqual(header.change, .date(dateText(date)))
        let restored = Helper.factory().createHeader(for: Helper.params(), locale: Helper.locale)
        XCTAssertEqual(restored.price, "999 TAO")
        XCTAssertEqual(restored.change, .hidden)
    }

    func testFullCoverageRetainsReturnAndLatestScrubUsesTheStoredDate() {
        let history = Helper.history(points: [Helper.point(daysBefore: 7, value: 2), Helper.point(daysBefore: 0, value: 4)], change: 1)
        let factory = Helper.factory()
        let header = factory.createHeader(for: Helper.params(history: history), locale: Helper.locale)
        guard case let .value(text, isRising) = header.change else { return XCTFail("Expected covered-period return") }
        XCTAssertTrue(text.contains("100"))
        XCTAssertTrue(text.contains("7D"))
        XCTAssertTrue(isRising)
        let selected = factory.createHeader(for: Helper.params(history: history, selection: .point(sourceIndex: 1)), locale: Helper.locale)
        guard case let .value(selectedText, _) = selected.change else { return XCTFail("Expected selected return") }
        XCTAssertTrue(selectedText.contains(dateText(Helper.end)))
        XCTAssertFalse(selectedText.contains("7D"))
        XCTAssertEqual(selected.price, "4 TAO")
    }

    func testMissingZeroAndStaleBaselinesNeverClaimAPeriodReturn() {
        let points = [Helper.point(daysBefore: 7, value: 2), Helper.point(daysBefore: 0, value: 4)]
        let cases = [
            Helper.history(points: points, change: nil),
            Helper.history(points: [Helper.point(daysBefore: 7, value: 0), points[1]], change: 1),
            Helper.history(points: [points[0], Helper.point(daysBefore: 1, value: 4)], change: 1),
            Helper.history(change: 1)
        ]
        for history in cases {
            let params = Helper.params(history: history)
            XCTAssertEqual(Helper.factory().createHeader(for: params, locale: Helper.locale).change, .hidden)
            let selected = Helper.factory().createHeader(for: Helper.params(history: history, selection: .point(sourceIndex: 1)), locale: Helper.locale)
            XCTAssertEqual(selected.change, .date(dateText(history.points[1].date)))
        }
    }

    func testClippedEndpointsRecalculateReturnWithoutUsingThePredecessor() throws {
        let history = Helper.history(points: [
            Helper.point(daysBefore: 8, value: 1),
            Helper.point(daysBefore: 7 - 1.0 / 24, value: 2),
            Helper.point(daysBefore: 0, value: 3),
            Helper.point(daysBefore: -1, value: 100)
        ], change: 99)
        let params = Helper.params(history: history)
        let factory = Helper.factory()
        XCTAssertEqual(factory.displayChange(history: history, params: params), 0.5)
        let series = try Helper.series(Helper.chart(factory.createWidget(for: params, locale: Helper.locale)))
        XCTAssertEqual(series.predecessor?.date, history.points[0].date)
        XCTAssertEqual(series.points.map(\.sourceIndex), [1, 2])
        XCTAssertFalse(series.hasMissingPrefix)
    }

    func testEmptySingletonOutsideAndNonfiniteHistoriesRemainUnavailable() {
        let cases: [[SubtensorPricePoint]] = [
            [], [Helper.point(daysBefore: 0, value: 1)],
            [Helper.point(daysBefore: 10, value: 1), Helper.point(daysBefore: 8, value: 2)],
            [Helper.point(daysBefore: -1, value: 1), Helper.point(daysBefore: -2, value: 2)],
            [SubtensorPricePoint(date: Helper.end, taoPerAlpha: .nan, fiatPerAlpha: .nan),
             SubtensorPricePoint(date: Date(timeIntervalSince1970: .infinity), taoPerAlpha: 1, fiatPerAlpha: 1)]
        ]
        for points in cases {
            let widget = Helper.factory().createWidget(for: Helper.params(history: Helper.history(points: points)), locale: Helper.locale)
            guard case .unavailable = widget.chart else { return XCTFail("Expected unavailable for \(points)") }
            XCTAssertEqual(widget.header.price, "999 TAO")
            XCTAssertEqual(widget.header.change, .hidden)
        }
    }

    func testFilteringAndSortingPreserveOriginalSourceIdentity() throws {
        let history = Helper.history(points: [
            Helper.point(daysBefore: 0, value: 4), Helper.point(daysBefore: 1, value: .nan),
            Helper.point(daysBefore: 3, value: 2), Helper.point(daysBefore: 1, value: 3)
        ])
        let widget = Helper.factory().createWidget(for: Helper.params(history: history), locale: Helper.locale)
        let series = try Helper.series(Helper.chart(widget))
        XCTAssertEqual(series.points.map(\.sourceIndex), [2, 3, 0])
        let header = Helper.factory().createHeader(for: Helper.params(history: history, selection: .point(sourceIndex: 3)), locale: Helper.locale)
        XCTAssertEqual(header.price, "3 TAO")
        XCTAssertEqual(header.change, .date(dateText(history.points[3].date)))
        let invalid = Helper.factory().createHeader(for: Helper.params(history: history, selection: .point(sourceIndex: 1)), locale: Helper.locale)
        XCTAssertEqual(invalid.price, "—")
    }

    func testLoadingNotListedAndFailedKeepTheirDistinctPresentation() {
        let states: [SubtensorSubnetHistoryState] = [.loading, .notListed, .failed]
        for state in states {
            let params = SubtensorPriceWidgetParams(
                caption: "Price", spotPrice: 999, history: state, period: .week,
                isFiat: false, taoPrice: nil, currencyId: nil, currency: nil,
                chartEndDate: Helper.end, selection: nil
            )
            let widget = Helper.factory().createWidget(for: params, locale: Helper.locale)
            XCTAssertEqual(widget.header.price, "999 TAO")
            switch state {
            case .loading:
                XCTAssertEqual(widget.chart, .loading)
                XCTAssertEqual(widget.header.change, .loading)
            case .notListed:
                guard case .unavailable = widget.chart else { return XCTFail("Expected unavailable") }
                XCTAssertEqual(widget.header.change, .hidden)
                XCTAssertFalse(widget.periods.isEnabled)
            case .failed:
                guard case let .failed(_, action) = widget.chart else { return XCTFail("Expected retry") }
                XCTAssertFalse(action.isEmpty)
                XCTAssertEqual(widget.header.change, .hidden)
                XCTAssertTrue(widget.periods.isEnabled)
            case .available:
                XCTFail("Unexpected fixture")
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        DateFormatter.chartEntryDate.value(for: Helper.locale).string(from: date)
    }
}
