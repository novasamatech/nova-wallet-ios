@testable import novawallet
import XCTest

final class SubtensorSubnetParametersTests: XCTestCase {
    func testReservesSplitEmissionPermitCountAndEstimatedAgeUseSnapshotInputs() throws {
        let subnet = Self.subnet(tao: 20, alpha: 80, emission: 2)
        let other = Self.subnet(netuid: 2, emission: 6)
        let result = snapshot(rows: [subnet, other])
        XCTAssertEqual(result.poolSplit, 0.2)
        XCTAssertEqual(result.emission, 0.25)
        XCTAssertEqual(result.validators, 2)
        XCTAssertEqual(result.age, 1200)
        XCTAssertEqual(result.alphaPrice, 500_000_000)
        XCTAssertEqual(result.blockHash, "snapshot")
        XCTAssertEqual(result.blockNumber, 200)
    }

    func testPartialOrDuplicatePopulationNeverCreatesEmissionDenominator() {
        let subnet = Self.subnet()
        for rows in [[subnet, nil], [subnet, subnet]] {
            XCTAssertNil(snapshot(rows: rows).emission)
            XCTAssertFalse(snapshot(rows: rows).isPopulationComplete)
        }
        XCTAssertEqual(snapshot(rows: [subnet, nil], enabled: false).emission, 0)
        XCTAssertNil(snapshot(rows: [subnet], enabled: nil).emission)
        XCTAssertNil(snapshot(rows: [Self.subnet(emission: 0)]).emission)
    }

    func testDifferentRegistrationDiscardsAllSubnetFacets() {
        let result = snapshot(rows: [Self.subnet(registeredAt: 101)], enabled: false)
        XCTAssertNil(result.subnet)
        XCTAssertNil(result.alphaPrice)
        XCTAssertNil(result.validators)
        XCTAssertNil(result.age)
        XCTAssertNil(result.emission)
    }

    func testMissingFacetsKeepReservesAndEmptyPermitVectorMeansZero() {
        let result = snapshot(rows: [Self.subnet()], permits: [], blockTime: nil)
        XCTAssertNotNil(result.subnet)
        XCTAssertEqual(result.validators, 0)
        XCTAssertNil(result.age)
        XCTAssertNil(snapshot(rows: [Self.subnet()], permits: nil).validators)
    }

    func testAgeAndEmptyPoolBounds() {
        XCTAssertNil(snapshot(rows: [Self.subnet(tao: 0, alpha: 0)]).poolSplit)
        XCTAssertNil(snapshot(rows: [Self.subnet()], head: 99).age)
        XCTAssertNil(snapshot(rows: [Self.subnet()], blockTime: 0).age)
        XCTAssertNil(snapshot(rows: [Self.subnet()], blockTime: UInt64.max).age)
        let zero = SubtensorSubnetParameters(
            ref: .init(netuid: 1, registeredAt: 0),
            blockHash: "x",
            rows: [Self.subnet(registeredAt: 0)],
            prices: nil,
            blockNumber: 100,
            permits: nil,
            emissionEnabled: nil,
            blockTime: 12000
        )
        XCTAssertNil(zero.age)
    }

    private func snapshot(
        rows: [SubtensorStakingPallet.DynamicInfo?], enabled: Bool? = true,
        permits: [Bool]? = [true, false, true], head: BlockNumber = 200, blockTime: BlockTime? = 12000
    ) -> SubtensorSubnetParameters {
        SubtensorSubnetParameters(
            ref: .init(netuid: 1, registeredAt: 100), blockHash: "snapshot", rows: rows,
            prices: [.init(netuid: 1, price: 500_000_000)], blockNumber: head,
            permits: permits, emissionEnabled: enabled, blockTime: blockTime
        )
    }

    static func subnet(
        netuid: UInt16 = 1, registeredAt: UInt64 = 100,
        tao: Balance = 20, alpha: Balance = 80, emission: Balance = 2
    ) -> SubtensorStakingPallet.DynamicInfo {
        var info = SubtensorFlowChainWorld.dynamicInfo(
            netuid: netuid, name: "Subnet", symbol: "ش", registeredAt: registeredAt, tempo: 360
        )
        info.taoIn = tao
        info.alphaIn = alpha
        info.taoInEmission = emission
        info.emission = 999_999
        return info
    }
}
