# Subtensor Portfolio Chart Zero-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the "Your Bittensor" header chart draw a zero line before the first backend history point, carry the last value across gaps, and keep the live point, so an account that tao.app began tracking recently shows "0, then a jump" instead of a stretched line or "Chart unavailable".

**Architecture:** One pure function changes: `SubtensorPortfolioValueSeriesCalculator.calculate` (iOS). It builds the series on the window grid (`window.start` to `window.end` with `period.sampleStep`) instead of on the returned points. Grid instants before the first completed point are zero, instants without a bucket after it carry the previous value, instants at or after `now` are dropped, then the live chain point is appended as before. The backend contract, the position screen and Android are untouched.

**Tech Stack:** Swift, XCTest, xcodebuild (novawalletTests scheme), Dev configuration for device screenshots.

Spec: `docs/superpowers/specs/2026-10-21-subtensor-portfolio-chart-zero-fill-design.md`

---

## File structure

- Modify: `novawallet/Modules/Staking/Subtensor/Model/SubtensorPortfolioValueSeriesCalculator.swift`
  - `calculate` gains a grid step between "map completed points" and "append live point".
  - New private helpers `gridPoints(...)` and `carriedPoint(...)` in the existing private extension.
- Modify: `novawalletTests/Modules/Staking/SubtensorStaking/SubtensorPortfolioValueSeriesCalculatorTests.swift`
  - Rewrite the weekly test to the grid expectation and add four tests with a JSON fixture builder.

Test command used throughout (unit tests only, single class):

```bash
cd ~/nova-wallet-ios && xcodebuild test \
  -workspace novawallet.xcworkspace -scheme novawallet \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:novawalletTests/SubtensorPortfolioValueSeriesCalculatorTests \
  -skipPackagePluginValidation -skipMacroValidation 2>&1 | grep -E 'Test Case|error:|\*\* TEST'
```

Expected on success: every `Test Case ... passed` line and `** TEST SUCCEEDED **`.

---

### Task 1: Fixture builder and failing tests

**Files:**
- Test: `novawalletTests/Modules/Staking/SubtensorStaking/SubtensorPortfolioValueSeriesCalculatorTests.swift`

- [ ] **Step 1: Replace the test file with the new tests**

```swift
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
        XCTAssertEqual(try series.points[0], point(at: "2026-10-07T13:00:00Z", taoValue: "12.5", fiatValue: "4875.25"))
        XCTAssertEqual(try series.points[24], point(at: "2026-10-08T13:00:00Z", taoValue: "12.5", fiatValue: "4875.25"))
        XCTAssertEqual(try series.points[84], point(at: "2026-10-11T01:00:00Z", taoValue: "13.1", fiatValue: "5240"))
        XCTAssertEqual(try series.points[166], point(at: "2026-10-14T11:00:00Z", taoValue: "13.1", fiatValue: "5240"))
        XCTAssertEqual(try series.points[167], point(at: "2026-10-14T12:00:00Z", taoValue: "13.6", fiatValue: "5480.8"))
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
        XCTAssertEqual(try series.points.first, point(at: "2026-09-21T13:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(try series.points[179], point(at: "2026-10-21T09:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertTrue(series.points.dropLast().allSatisfy { $0.taoValue == 0 && $0.fiatValue == 0 })
        XCTAssertEqual(try series.points.last, point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
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
        XCTAssertEqual(try series.points[21], point(at: "2026-10-21T10:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(try series.points[22], point(at: "2026-10-21T11:00:00Z", taoValue: "12.44", fiatValue: "3397.51"))
        XCTAssertEqual(try series.points[23], point(at: "2026-10-21T12:00:00Z", taoValue: "12.44", fiatValue: "3397.51"))
        XCTAssertEqual(try series.points[24], point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
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
        XCTAssertEqual(try series.points[269], point(at: "2026-10-21T05:00:00Z", taoValue: "0", fiatValue: "0"))
        XCTAssertEqual(try series.points.last, point(at: "2026-10-21T12:20:00Z", taoValue: "12.44", fiatValue: "3396.12"))
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
        XCTAssertEqual(try series.points[0], point(at: "2026-10-20T13:00:00Z", taoValue: "10", fiatValue: "2700"))
        XCTAssertEqual(try series.points[1], point(at: "2026-10-20T14:00:00Z", taoValue: "10", fiatValue: "2710"))
        XCTAssertEqual(try series.points[3], point(at: "2026-10-20T16:00:00Z", taoValue: "10", fiatValue: "2730"))
        XCTAssertEqual(try series.points[4], point(at: "2026-10-20T16:30:00Z", taoValue: "10", fiatValue: "2800"))
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
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run the test command from the file structure section.

Expected: `testAllTimeHistoryKeepsEveryRegisteredPointAndItsChange` passes; the five grid tests fail on point counts (for example `XCTAssertEqual failed: ("3") is not equal to ("168")`). If the file does not compile, fix the fixture code before continuing; do not touch the calculator yet.

- [ ] **Step 3: Commit the tests**

```bash
git add novawalletTests/Modules/Staking/SubtensorStaking/SubtensorPortfolioValueSeriesCalculatorTests.swift
git commit -m "test: describe the zero-filled portfolio value series"
```

---

### Task 2: Grid construction in the calculator

**Files:**
- Modify: `novawallet/Modules/Staking/Subtensor/Model/SubtensorPortfolioValueSeriesCalculator.swift` (the `calculate` function and the private extension below it)

- [ ] **Step 1: Replace `calculate` so it goes through the grid**

Replace the whole `enum SubtensorPortfolioValueSeriesCalculator { ... }` block with:

```swift
enum SubtensorPortfolioValueSeriesCalculator {
    static func calculate(
        portfolio: SubtensorPortfolio,
        histories: SubtensorPortfolioPriceHistories,
        currentTaoPrice: Decimal,
        precision: Int16,
        now: Date = Date()
    ) -> SubtensorPortfolioValueSeries {
        let taoFiat = histories.taoFiat?.items.filter { $0.value > 0 }.sorted { $0.startedAt < $1.startedAt }
        let taoFiatTimes = taoFiat?.map { TimeInterval($0.startedAt) } ?? []

        let completed = histories.portfolio.points.filter(\.completed).compactMap { point in
            valuePoint(
                for: point,
                taoFiat: taoFiat,
                taoFiatTimes: taoFiatTimes,
                tolerance: histories.period.coverageTolerance
            )
        }

        var points = gridPoints(
            from: completed,
            history: histories.portfolio,
            taoFiat: taoFiat,
            taoFiatTimes: taoFiatTimes,
            tolerance: histories.period.coverageTolerance,
            before: now
        )

        if
            portfolio.isFullyPriced,
            let totalTao = Decimal.fromSubstrateAmount(portfolio.pricedTaoValue, precision: precision),
            points.last.map({ $0.date < now }) ?? true {
            let livePrice = histories.taoFiat == nil
                ? reportedUsdPerTao(in: histories, now: now) ?? currentTaoPrice
                : currentTaoPrice

            points.append(SubtensorPortfolioValuePoint(date: now, taoValue: totalTao, fiatValue: totalTao * livePrice))
        }

        return SubtensorPortfolioValueSeries(
            points: points,
            changeInFiat: change(of: points, in: histories.portfolio)
        )
    }
}
```

- [ ] **Step 2: Add the grid helpers to the private extension**

Insert these two functions into `private extension SubtensorPortfolioValueSeriesCalculator`, right after `valuePoint(...)`:

```swift
    /// Walks the server window with the period step. Each instant takes the newest completed point
    /// at or before it that was not taken yet, carries the previous value when there is none, and is
    /// zero before the first completed point. Instants at or after `now` are left to the live point.
    static func gridPoints(
        from completed: [SubtensorPortfolioValuePoint],
        history: BittensorApi.PortfolioHistoryCollection,
        taoFiat: [PriceHistoryItem]?,
        taoFiatTimes: [TimeInterval],
        tolerance: TimeInterval,
        before now: Date
    ) -> [SubtensorPortfolioValuePoint] {
        guard
            let start = BittensorApi.instant(from: history.window.start),
            let end = BittensorApi.instant(from: history.window.end),
            start <= end else {
            return completed
        }

        let step = history.period.sampleStep
        let sorted = completed.sorted { $0.date < $1.date }
        var nextIndex = sorted.startIndex
        var last: SubtensorPortfolioValuePoint?
        var points: [SubtensorPortfolioValuePoint] = []
        var instant = start

        while instant <= end, instant < now {
            var matched: SubtensorPortfolioValuePoint?

            while nextIndex < sorted.endIndex, sorted[nextIndex].date <= instant {
                matched = sorted[nextIndex]
                nextIndex += 1
            }

            if let matched {
                points.append(matched)
                last = matched
            } else if let last {
                points.append(
                    carriedPoint(last, at: instant, taoFiat: taoFiat, taoFiatTimes: taoFiatTimes, tolerance: tolerance)
                )
            } else {
                points.append(SubtensorPortfolioValuePoint(date: instant, taoValue: 0, fiatValue: 0))
            }

            instant = instant.addingTimeInterval(step)
        }

        return points
    }

    /// Repeats the last known TAO total at a later instant, repriced with the TAO fiat history when it
    /// covers that instant and carried as is otherwise.
    static func carriedPoint(
        _ last: SubtensorPortfolioValuePoint,
        at instant: Date,
        taoFiat: [PriceHistoryItem]?,
        taoFiatTimes: [TimeInterval],
        tolerance: TimeInterval
    ) -> SubtensorPortfolioValuePoint {
        guard
            let taoFiat,
            let index = SubtensorPriceSeries.nearestIndex(
                to: instant.timeIntervalSince1970,
                in: taoFiatTimes,
                tolerance: tolerance
            ) else {
            return SubtensorPortfolioValuePoint(date: instant, taoValue: last.taoValue, fiatValue: last.fiatValue)
        }

        return SubtensorPortfolioValuePoint(
            date: instant,
            taoValue: last.taoValue,
            fiatValue: last.taoValue * taoFiat[index].value
        )
    }
```

- [ ] **Step 3: Run the tests to verify they pass**

Run the test command from the file structure section.

Expected: all six `Test Case` lines report `passed` and `** TEST SUCCEEDED **`.

If `testWeeklyHistory...` fails on index 84: the point at `2026-10-11T01:00:00Z` is 84 hours after `2026-10-07T13:00:00Z`, so index 84 must hold the real point with its own timestamp. Check that the matching loop uses `<=` and that real points keep their own `date`.

- [ ] **Step 4: Run the whole Subtensor test folder once**

```bash
cd ~/nova-wallet-ios && xcodebuild test \
  -workspace novawallet.xcworkspace -scheme novawallet \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:novawalletTests/SubtensorPortfolioBuilderTests \
  -only-testing:novawalletTests/SubtensorPortfolioValueSeriesCalculatorTests \
  -skipPackagePluginValidation -skipMacroValidation 2>&1 | grep -E 'Test Case|error:|\*\* TEST'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add novawallet/Modules/Staking/Subtensor/Model/SubtensorPortfolioValueSeriesCalculator.swift
git commit -m "fix(subtensor): draw the portfolio chart on the window grid with zeros before the first history point"
```

---

### Task 3: Screenshots on the reference account

**Files:** none in the repository. Output: four PNGs in the scratchpad directory.

Prerequisite: the iPhone must be connected over USB and unlocked. `xcrun devicectl list devices` must show `Stepan’s iPhone` as `connected`. If it is `unavailable`, stop and ask the user to plug the phone in; the simulator cannot be used because App Attest is unsupported there and every backend call fails with `deviceBound`.

- [ ] **Step 1: Build the Dev configuration for the device**

```bash
cd ~/nova-wallet-ios && xcodebuild build \
  -workspace novawallet.xcworkspace -scheme novawallet -configuration Dev \
  -destination 'platform=iOS,id=00008110-00140C4C2128401E' \
  -derivedDataPath /private/tmp/claude-501/-Users-stepanlavrentev-nova-wallet-ios/de160545-013e-48fe-9898-432959e6325d/scratchpad/dd \
  -allowProvisioningUpdates -skipPackagePluginValidation -skipMacroValidation 2>&1 | grep -E 'error:|\*\* BUILD'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Install and launch**

```bash
APP=$(find /private/tmp/claude-501/-Users-stepanlavrentev-nova-wallet-ios/de160545-013e-48fe-9898-432959e6325d/scratchpad/dd/Build/Products/Dev-iphoneos -maxdepth 1 -name '*.app' | head -1)
xcrun devicectl device install app --device 00008110-00140C4C2128401E "$APP"
xcrun devicectl device process launch --device 00008110-00140C4C2128401E "$(defaults read "$APP/Info.plist" CFBundleIdentifier)"
```

Expected: `App installed` and a launch confirmation.

- [ ] **Step 3: Capture the four periods**

On the phone: open the wallet that holds `5CLpYny5hRM2NFNBAge6cnVC1TmWE8LYWgefuEhjTquLxA9S` (watch-only import is enough), open Staking, Bittensor, "Your Bittensor". For each of 1D, 7D, 30D and 90D run:

```bash
xcrun devicectl device screenshot --device 00008110-00140C4C2128401E \
  /private/tmp/claude-501/-Users-stepanlavrentev-nova-wallet-ios/de160545-013e-48fe-9898-432959e6325d/scratchpad/portfolio-<period>.png
```

Expected: 30D shows a flat zero line until 11:00 UTC on 2026-10-21 and then a jump to 12.44 TAO; 90D shows zeros then the jump at the live point; 1D and 7D show zeros, the 11:00 point and the live point.

- [ ] **Step 4: Attach the screenshots to the report**

Read each PNG with the Read tool and include the paths in the final message to the user.
