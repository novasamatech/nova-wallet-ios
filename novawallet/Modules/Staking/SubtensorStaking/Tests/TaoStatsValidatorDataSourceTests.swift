import XCTest
@testable import novawallet

/// [TEMP-TAOSTATS] Phase B unit coverage for the TaoStats REST data source
/// parser. Exercises the pure `parse(jsonData:)` helper so decoding and
/// field-interpretation logic can be verified without hitting the network.
final class TaoStatsValidatorDataSourceTests: XCTestCase {
    // MARK: - Happy path

    func test_parse_twoValidatorFixture_decodesAllFields() throws {
        let json = Self.twoValidatorFixture.data(using: .utf8)!

        let rows = try TaoStatsValidatorDataSource.parse(jsonData: json)

        XCTAssertEqual(rows.count, 2)

        let taostats = rows.first { $0.ss58 == "5GKH9FPPnWSUoeeTJp19wVtd84XqFW4pyK2ijV2GsFbhTrP1" }
        XCTAssertNotNil(taostats)
        XCTAssertEqual(taostats?.name, "Taostats")
        XCTAssertEqual(taostats?.totalStake.description, "767381773437417")
        XCTAssertEqual(taostats?.ownStake.description, "457978988665")
        XCTAssertEqual(taostats?.commission ?? 0, 0.0899977, accuracy: 1e-6)
        XCTAssertEqual(taostats?.nominatorCount, 6691)
        XCTAssertEqual(taostats?.apr ?? 0, 0.16534, accuracy: 1e-6)
        XCTAssertEqual(taostats?.hotkey.count, 32)

        let opsec = rows.first { $0.ss58 == "5DXVbg1vRYTsJnc3nLKp3UNjpuGfpvvTdcGXNTcd8ukx95B2" }
        XCTAssertNotNil(opsec)
        XCTAssertEqual(opsec?.name, "OPSEC")
        XCTAssertEqual(opsec?.totalStake.description, "500000000000000")
        XCTAssertEqual(opsec?.ownStake.description, "200000000000")
        XCTAssertEqual(opsec?.commission ?? 0, 0.18, accuracy: 1e-6)
        XCTAssertEqual(opsec?.nominatorCount, 3200)
    }

    // MARK: - APR fallback

    func test_parse_missingApr30DayAverage_fallsBackToDailyApr() throws {
        let json = Self.missingAprAverageFixture.data(using: .utf8)!

        let rows = try TaoStatsValidatorDataSource.parse(jsonData: json)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.apr ?? 0, 0.17099, accuracy: 1e-6)
    }

    // MARK: - SS58 skip

    func test_parse_invalidSS58RowIsSkipped() throws {
        let json = Self.invalidSS58Fixture.data(using: .utf8)!

        let rows = try TaoStatsValidatorDataSource.parse(jsonData: json)

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.ss58, "5GKH9FPPnWSUoeeTJp19wVtd84XqFW4pyK2ijV2GsFbhTrP1")
    }

    // MARK: - Empty data

    func test_parse_emptyDataArray_returnsEmpty() throws {
        let json = #"{ "data": [] }"#.data(using: .utf8)!

        let rows = try TaoStatsValidatorDataSource.parse(jsonData: json)

        XCTAssertTrue(rows.isEmpty)
    }

    // MARK: - Fixtures

    private static let twoValidatorFixture = #"""
    {
      "data": [
        {
          "hotkey": { "ss58": "5GKH9FPPnWSUoeeTJp19wVtd84XqFW4pyK2ijV2GsFbhTrP1" },
          "name": "Taostats",
          "nominators": 6691,
          "stake": "767381773437417",
          "validator_stake": "457978988665",
          "take": "0.08999771114671549554",
          "apr": "0.17099",
          "apr_30_day_average": "0.16534"
        },
        {
          "hotkey": { "ss58": "5DXVbg1vRYTsJnc3nLKp3UNjpuGfpvvTdcGXNTcd8ukx95B2" },
          "name": "OPSEC",
          "nominators": 3200,
          "stake": "500000000000000",
          "validator_stake": "200000000000",
          "take": "0.18",
          "apr": "0.14",
          "apr_30_day_average": "0.15"
        }
      ]
    }
    """#

    private static let missingAprAverageFixture = #"""
    {
      "data": [
        {
          "hotkey": { "ss58": "5GKH9FPPnWSUoeeTJp19wVtd84XqFW4pyK2ijV2GsFbhTrP1" },
          "name": "AprFallback",
          "nominators": 1,
          "stake": "1",
          "validator_stake": "1",
          "take": "0.1",
          "apr": "0.17099",
          "apr_30_day_average": null
        }
      ]
    }
    """#

    private static let invalidSS58Fixture = #"""
    {
      "data": [
        {
          "hotkey": { "ss58": "not-a-real-ss58-string" },
          "name": "Broken",
          "nominators": 1,
          "stake": "1",
          "validator_stake": "1",
          "take": "0.1",
          "apr": "0.1",
          "apr_30_day_average": "0.1"
        },
        {
          "hotkey": { "ss58": "5GKH9FPPnWSUoeeTJp19wVtd84XqFW4pyK2ijV2GsFbhTrP1" },
          "name": "Good",
          "nominators": 1,
          "stake": "1",
          "validator_stake": "1",
          "take": "0.1",
          "apr": "0.1",
          "apr_30_day_average": "0.1"
        }
      ]
    }
    """#
}
