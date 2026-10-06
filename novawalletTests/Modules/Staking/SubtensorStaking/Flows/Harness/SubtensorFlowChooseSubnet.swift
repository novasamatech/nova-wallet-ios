import Foundation
import Operation_iOS
import XCTest
@testable import novawallet

extension SubtensorFlowTestCase {
    func staleDocument(_ document: [String: Any]) -> [String: Any] {
        document.reduce(into: [String: Any]()) { result, entry in
            result[entry.key] = entry.key == "freshness" ? "STALE" : staleValue(entry.value)
        }
    }

    func staleValue(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return staleDocument(object)
        }

        return (value as? [Any])?.map(staleValue) ?? value
    }

    func serveWeekCharts() throws {
        let weekStart = try milliseconds("2026-09-17T09:00:00Z")
        let weekEnd = try milliseconds("2026-09-24T09:00:00Z")
        let chutesEnd = try decimal("23.28")

        SubtensorFlowURLProtocol.serveMarketChart(coinId: "bittensor", days: "7", points: [
            SubtensorFlowPricePoint(milliseconds: weekStart, value: 340),
            SubtensorFlowPricePoint(milliseconds: weekEnd, value: 350)
        ])

        SubtensorFlowURLProtocol.serveMarketChart(coinId: "chutes", days: "7", points: [
            SubtensorFlowPricePoint(milliseconds: weekStart, value: 20),
            SubtensorFlowPricePoint(milliseconds: weekEnd, value: chutesEnd)
        ])

        SubtensorFlowURLProtocol.serveSubnetMarkets(chutesWeekStart: 20, end: chutesEnd)
    }

    func listedSubnetRefs(in world: SubtensorFlowWorld) throws -> [SubtensorSubnetRef] {
        let catalogue = try run(world.earnServices.catalogueService.createCatalogueWrapper())
        let subnetsInfo = try fetchSubnetsInfo(from: world.sharedState.subnetsService)

        return SubtensorSubnetListBuilder.entries(from: catalogue, subnetsInfo: subnetsInfo).map(\.subnet.ref)
    }

    func assertChutesWeekPrices(
        _ prices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>],
        chutes: SubtensorSubnetRef
    ) {
        XCTAssertEqual(prices.count, 10)
        XCTAssertEqual(prices.values.filter { $0 == .notListed }.count, 9)

        guard case let .available(summary)? = prices[chutes] else {
            XCTFail("Expected the Chutes week prices, got \(String(describing: prices[chutes]))")
            return
        }

        XCTAssertEqual(try flowDouble(summary.change), 7915.2 / 7000 - 1, accuracy: 1e-9)
        assertFlowDoubles(summary.sparkline, [20.0 / 340, 23.28 / 350])
    }

    func assertChutesWeekHistory(_ result: SubtensorPriceHistoryResult, subnet: SubtensorSubnetRef) {
        guard case let .available(history) = result else {
            XCTFail("Expected the Chutes week history, got \(result)")
            return
        }

        XCTAssertEqual(history.subnet, subnet)
        XCTAssertEqual(history.period, .week)
        XCTAssertEqual(history.points.count, 2)
        XCTAssertEqual(try flowDouble(history.changeInTao), 7915.2 / 7000 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(history.changeInFiat), 0.164, accuracy: 1e-9)
    }

    func item(
        _ member: BittensorApiFixtureWorld.Member,
        in directory: SubtensorValidatorDirectory
    ) throws -> SubtensorValidatorDirectoryItem {
        let hotkey = try SubtensorFlowChainWorld.hotkey(member)

        return try XCTUnwrap(directory.items.first { $0.hotkey == hotkey })
    }

    func hotkeys(_ members: [BittensorApiFixtureWorld.Member]) throws -> [AccountId] {
        try members.map { try SubtensorFlowChainWorld.hotkey($0) }
    }

    func milliseconds(_ text: String) throws -> UInt64 {
        UInt64(try date(text).timeIntervalSince1970 * 1000)
    }
}
