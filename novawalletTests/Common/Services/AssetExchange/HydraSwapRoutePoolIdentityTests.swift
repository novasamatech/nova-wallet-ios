import XCTest
@testable import novawallet

final class HydraSwapRoutePoolIdentityTests: XCTestCase {
    typealias Component = HydraDx.RemoteSwapRoute.Component

    func testStableswapComponentsOfTheSamePoolShareIdentity() {
        // given
        let addLiquidity = Component(assetIn: 22, assetOut: 110, type: .stableswap(110))
        let withdraw = Component(assetIn: 110, assetOut: 222, type: .stableswap(110))

        // then
        XCTAssertEqual(addLiquidity.poolIdentifier, withdraw.poolIdentifier)
    }

    func testStableswapComponentsOfDifferentPoolsDontShareIdentity() {
        // given
        let firstPool = Component(assetIn: 22, assetOut: 222, type: .stableswap(110))
        let secondPool = Component(assetIn: 10, assetOut: 222, type: .stableswap(111))

        // then
        XCTAssertNotEqual(firstPool.poolIdentifier, secondPool.poolIdentifier)
    }

    func testOmnipoolComponentsAlwaysShareIdentity() {
        // given
        let first = Component(assetIn: 222, assetOut: 1001, type: .omnipool)
        let second = Component(assetIn: 1001, assetOut: 0, type: .omnipool)

        // then
        XCTAssertEqual(first.poolIdentifier, second.poolIdentifier)
    }

    func testPairPoolsShareIdentityOnlyForTheSamePair() {
        // given
        let xykForward = Component(assetIn: 5, assetOut: 10, type: .xyk)
        let xykBackward = Component(assetIn: 10, assetOut: 5, type: .xyk)
        let xykOther = Component(assetIn: 10, assetOut: 0, type: .xyk)
        let aaveSamePair = Component(assetIn: 5, assetOut: 10, type: .aave)

        // then
        XCTAssertEqual(xykForward.poolIdentifier, xykBackward.poolIdentifier)
        XCTAssertNotEqual(xykForward.poolIdentifier, xykOther.poolIdentifier)
        XCTAssertNotEqual(xykForward.poolIdentifier, aaveSamePair.poolIdentifier)
    }
}
