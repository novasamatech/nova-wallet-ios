import BigInt
@testable import novawallet
import XCTest

final class SubtensorStakeTargetTests: XCTestCase {
    private let spot = Balance(7_683_255)
    private let tolerance = BigRational(numerator: 5, denominator: 1000)

    private func makeSubnetTarget(
        netuid: UInt16 = 1,
        symbol: String = "α"
    ) -> SubtensorStakeTarget {
        .subnet(info: makeDynamicInfo(netuid: netuid, symbol: symbol), price: spot)
    }

    private func makeDynamicInfo(netuid: UInt16, symbol: String) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data("Apex".utf8),
            tokenSymbol: Data(symbol.utf8),
            tempo: 99,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }

    func testRootTargetNeverProducesStakeLimitPrice() {
        XCTAssertNil(SubtensorStakeTarget.root.stakeLimitPrice(spot: spot, tolerance: tolerance))
    }

    func testRootTargetNeverProducesUnstakeLimitPrice() {
        XCTAssertNil(SubtensorStakeTarget.root.unstakeLimitPrice(spot: spot, tolerance: tolerance))
    }

    func testSubnetTargetProducesFlooredBuyLimit() {
        XCTAssertEqual(
            makeSubnetTarget().stakeLimitPrice(spot: spot, tolerance: tolerance),
            7_721_671
        )
    }

    func testSubnetTargetProducesCeiledSellLimit() {
        XCTAssertEqual(
            makeSubnetTarget().unstakeLimitPrice(spot: spot, tolerance: tolerance),
            7_644_839
        )
    }

    func testSubnetTargetWithoutSpotProducesNoLimit() {
        XCTAssertNil(makeSubnetTarget().stakeLimitPrice(spot: nil, tolerance: tolerance))
    }

    func testRootNetuidIsZero() {
        XCTAssertEqual(SubtensorStakeTarget.root.netuid, SubtensorStakingPallet.rootNetuid)
    }

    func testSubnetNetuidComesFromInfo() {
        XCTAssertEqual(makeSubnetTarget(netuid: 64).netuid, 64)
    }

    func testRootDisplayInfoKeepsTaoSymbol() {
        let taoInfo = AssetBalanceDisplayInfo.units(for: 9)

        XCTAssertEqual(SubtensorStakeTarget.root.assetDisplayInfo(basedOn: taoInfo), taoInfo)
    }

    func testSubnetDisplayInfoUsesTokenSymbol() {
        let displayInfo = makeSubnetTarget(symbol: "α").assetDisplayInfo(
            basedOn: AssetBalanceDisplayInfo.units(for: 9)
        )

        XCTAssertEqual(displayInfo.symbol, "α")
        XCTAssertEqual(displayInfo.assetPrecision, 9)
    }

    func testSubnetDisplayInfoFallsBackToNetuidTagWhenSymbolEmpty() {
        let displayInfo = makeSubnetTarget(netuid: 7, symbol: "").assetDisplayInfo(
            basedOn: AssetBalanceDisplayInfo.units(for: 9)
        )

        XCTAssertEqual(displayInfo.symbol, "SN7")
    }
}
