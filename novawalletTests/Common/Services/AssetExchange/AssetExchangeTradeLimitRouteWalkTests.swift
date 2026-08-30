import XCTest
@testable import novawallet
import Operation_iOS

final class AssetExchangeTradeLimitRouteWalkTests: XCTestCase {
    func testSellReportsTheFirstHopAsUserAdjustable() throws {
        let route = Self.route(direction: .sell, hops: [.breaching, .withinLimit])

        let check = try Self.run(route)

        XCTAssertEqual(check, .blocked(Self.failure(direction: .sell, isUserInputAdjustable: true)))
    }

    func testBuyReportsTheLastHopAsUserAdjustable() throws {
        let route = Self.route(direction: .buy, hops: [.withinLimit, .breaching])

        let check = try Self.run(route)

        XCTAssertEqual(check, .blocked(Self.failure(direction: .buy, isUserInputAdjustable: true)))
    }

    func testSellReportsTheHopAfterTheFirstAsNotUserAdjustable() throws {
        let route = Self.route(direction: .sell, hops: [.withinLimit, .breaching])

        let check = try Self.run(route)

        XCTAssertEqual(check, .blocked(Self.failure(direction: .sell, isUserInputAdjustable: false)))
    }

    func testFirstViolationInRouteOrderWins() throws {
        let route = Self.route(direction: .sell, hops: [.breaching, .breaching])

        let check = try Self.run(route)

        XCTAssertEqual(check, .blocked(Self.failure(direction: .sell, isUserInputAdjustable: true)))
    }

    func testRouteWhereEveryTradeLimitedHopIsWithinItsLimitIsWithinLimits() throws {
        let route = Self.route(direction: .sell, hops: [.withinLimit, .withinLimit])

        XCTAssertEqual(try Self.run(route), .withinLimits)
    }

    func testRouteWithoutAnyTradeLimitedHopIsWithinLimits() throws {
        let route = Self.route(direction: .sell, hops: [.unlimited, .unlimited])

        XCTAssertEqual(try Self.run(route), .withinLimits)
    }

    func testHopWithoutTradeLimitsDoesNotStopTheWalk() throws {
        let route = Self.route(direction: .sell, hops: [.unlimited, .breaching])

        XCTAssertEqual(
            try Self.run(route),
            .blocked(Self.failure(direction: .sell, isUserInputAdjustable: false))
        )
    }

    func testBreachWithNoCapBlocksWithoutAFailure() throws {
        let route = Self.route(direction: .sell, hops: [.breachingWithoutCap, .withinLimit])

        XCTAssertEqual(try Self.run(route), .blocked(nil))
    }

    func testDoubleErasedHopReportsItsBreach() throws {
        let route = Self.route(
            direction: .sell,
            hops: [.breaching, .withinLimit],
            doubleErased: true
        )

        XCTAssertEqual(
            try Self.run(route),
            .blocked(Self.failure(direction: .sell, isUserInputAdjustable: true))
        )
    }
}

private extension AssetExchangeTradeLimitRouteWalkTests {
    enum Hop {
        case unlimited
        case withinLimit
        case breaching
        case breachingWithoutCap
    }

    static let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)

    static let maxGivenAmount: Balance = 500

    static var limitedAsset: ChainAsset {
        ChainAsset(chain: chain, asset: chain.utilityAssets().first!)
    }

    static func route(
        direction: AssetConversion.Direction,
        hops: [Hop],
        doubleErased: Bool = false
    ) -> AssetExchangeRoute {
        let items = hops.map { hop in
            AssetExchangeRouteItem(
                edge: erased(edge(for: hop), doubleErased: doubleErased),
                amount: 1000,
                quote: 1000
            )
        }

        return AssetExchangeRoute(items: items, amount: 1000, direction: direction)
    }

    static func edge(for hop: Hop) -> StubAssetExchangeEdge {
        switch hop {
        case .unlimited:
            return StubAssetExchangeEdge(
                origin: limitedAsset.chainAssetId,
                destination: limitedAsset.chainAssetId,
                type: .hydraSwap,
                chain: limitedAsset.chain
            )
        case .withinLimit:
            return tradeLimitedEdge(verdict: .withinLimit)
        case .breaching:
            return tradeLimitedEdge(verdict: .exceeds(breach(maxGivenAmount: maxGivenAmount)))
        case .breachingWithoutCap:
            return tradeLimitedEdge(verdict: .exceeds(breach(maxGivenAmount: nil)))
        }
    }

    static func tradeLimitedEdge(
        verdict: AssetExchangeTradeLimitVerdict
    ) -> StubTradeLimitedExchangeEdge {
        StubTradeLimitedExchangeEdge(
            origin: limitedAsset.chainAssetId,
            destination: limitedAsset.chainAssetId,
            type: .hydraSwap,
            chain: limitedAsset.chain,
            verdict: verdict
        )
    }

    static func breach(maxGivenAmount: Balance?) -> AssetExchangeTradeLimitBreach {
        .init(
            maxGivenAmount: maxGivenAmount,
            minTradingLimit: nil,
            limitedAsset: limitedAsset
        )
    }

    static func erased(
        _ edge: StubAssetExchangeEdge,
        doubleErased: Bool
    ) -> AnyAssetExchangeEdge {
        doubleErased
            ? AnyAssetExchangeEdge(AnyAssetExchangeEdge(edge))
            : AnyAssetExchangeEdge(edge)
    }

    static func failure(
        direction: AssetConversion.Direction,
        isUserInputAdjustable: Bool
    ) -> AssetExchangeTradeLimitFailure {
        AssetExchangeTradeLimitFailure(
            limitedAsset: limitedAsset,
            maxGivenAmount: maxGivenAmount,
            minTradingLimit: nil,
            direction: direction,
            isUserInputAdjustable: isUserInputAdjustable
        )
    }

    static func run(_ route: AssetExchangeRoute) throws -> SwapPoolTradeLimitCheck {
        let wrapper = route.poolTradeLimitCheckWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
