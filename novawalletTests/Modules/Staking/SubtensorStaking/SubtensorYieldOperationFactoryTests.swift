@testable import novawallet
import XCTest

final class SubtensorYieldOperationFactoryTests: XCTestCase {
    private let netuid: UInt16 = 12
    private let reliableHotkey = Data(repeating: 0x21, count: 32)
    private let unreliableHotkey = Data(repeating: 0x22, count: 32)
    private let unverdictedHotkey = Data(repeating: 0x23, count: 32)

    func testOnlyReliableOrUnverdictedRatesAreTrusted() throws {
        let page = try decodePage(items: [
            try item(reliableHotkey, rate: "79.56", verdict: "\"RELIABLE\""),
            try item(unreliableHotkey, rate: "669990.45", verdict: "\"UNRELIABLE\""),
            try item(unverdictedHotkey, rate: "52.1", verdict: nil)
        ])

        let yields = SubtensorYieldOperationFactory.makeAlphaYields(
            netuid: netuid,
            result: BittensorApiResult(value: page, requestId: nil, isFromExpiredCache: false),
            logger: Logger.shared
        )

        XCTAssertEqual(yields.yields[reliableHotkey]?.annualRate, Decimal(string: "0.7956"))
        XCTAssertNil(yields.yields[unreliableHotkey]?.annualRate)
        XCTAssertEqual(yields.yields[unverdictedHotkey]?.annualRate, Decimal(string: "0.521"))
    }

    func testUnknownVerdictIsAContractViolation() throws {
        XCTAssertThrowsError(
            try decodePage(items: [try item(reliableHotkey, rate: "79.56", verdict: "\"MAYBE\"")])
        )
    }

    private func item(_ hotkey: AccountId, rate: String, verdict: String?) throws -> String {
        let address = try hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix))
        let reliability = verdict.map { ", \"rateReliability\": \($0)" } ?? ""

        return """
        {"metricKind": "ALPHA_VALIDATOR_APY", "netuid": \(netuid), "hotkey": "\(address)",
         "reportedRate": "\(rate)", "sourceTimestamp": "2026-10-20T09:10:24Z"\(reliability)}
        """
    }

    private func decodePage(items: [String]) throws -> BittensorApi.AlphaYieldCollection {
        let json = """
        {"items": [\(items.joined(separator: ","))],
         "pageInfo": {"page": 1, "pageSize": 100, "total": \(items.count), "nextPage": null},
         "meta": {"completeness": "COMPLETE",
                  "components": {"alphaYield": {"availability": "AVAILABLE",
                                                "asOf": "2026-10-20T09:31:00Z",
                                                "freshness": "FRESH"}}}}
        """

        let page = try JSONDecoder().decode(BittensorApi.AlphaYieldCollection.self, from: Data(json.utf8))
        try page.validateWire()

        return page
    }
}
