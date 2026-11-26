import XCTest
@testable import novawallet
import Operation_iOS

final class SwapPoolTradeLimitCheckTests: XCTestCase {
    static let existentialDeposits: [AssetModel.Id: Balance] = [1: 17_540_000, 2: 1_000_000_000_000, 4: 34]

    func testRouterDepositAtTheExistentialDepositPassesAndBelowItIsBlocked() throws {
        let atDeposit = makeRoute([hop(2, 1, amount: 1_000_000_000_000, quote: 20_000_000)], direction: .sell)
        XCTAssertEqual(try runCheck(atDeposit), .withinLimits)

        let belowDeposit = makeRoute([hop(2, 1, amount: 999_999_999_999, quote: 20_000_000)], direction: .sell)
        XCTAssertEqual(
            try runCheck(belowDeposit),
            .belowMinimum(.init(minimumAmount: 1_000_000_000_000, direction: .sell, isUserInputAdjustable: true))
        )
    }

    func testBuyBelowExistentialDepositAsksForTheNetMinimum() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let path = [hop(1, 2, amount: 0, quote: 0).edge]

        func buyRoute(net: Balance) -> AssetExchangeRoute {
            let gross = policy.grossingUpAmountOut(net, for: path)
            return makeRoute([hop(1, 2, amount: gross, quote: 20_000_000)], direction: .buy)
        }

        guard case let .belowMinimum(failure) = try runCheck(buyRoute(net: 500_000_000_000)) else {
            return XCTFail("expected the buy to be below the minimum")
        }

        XCTAssertTrue(failure.isUserInputAdjustable)

        let netMinimum = try XCTUnwrap(failure.userMinimum(chargesCommission: true))

        XCTAssertEqual(try runCheck(buyRoute(net: netMinimum)), .withinLimits)
        XCTAssertEqual(try runCheck(buyRoute(net: netMinimum - 1)), .belowMinimum(failure))
    }

    func testBuyBelowThePoolMinimumAsksForItEvenWhenThePaidAmountIsBelowItsDeposit() throws {
        let route = makeRoute([hop(4, 5, amount: 500, quote: 20, verdict: .belowMinimum(1000))], direction: .buy)

        XCTAssertEqual(
            try runCheck(route),
            .belowMinimum(.init(minimumAmount: 1000, direction: .buy, isUserInputAdjustable: true))
        )
    }

    func testFailedExistentialDepositFetchStillReportsTheTradingMinimum() throws {
        let route = makeRoute([hop(4, 5, amount: 306, quote: 305, verdict: .belowMinimum(1000))], direction: .sell)

        XCTAssertEqual(
            try runCheck(route) { _ in .createWithError(CommonError.noDataRetrieved) },
            .belowMinimum(.init(minimumAmount: 1000, direction: .sell, isUserInputAdjustable: true))
        )
    }

    func testFailedExistentialDepositFetchWithoutPoolLimitAsksForRetry() throws {
        let route = makeRoute([hop(2, 1, amount: 1_000_000_000_000, quote: 20_000_000)], direction: .sell)

        XCTAssertEqual(try runCheck(route) { _ in .createWithError(CommonError.noDataRetrieved) }, .minBalanceUnavailable)
    }
}

private extension SwapPoolTradeLimitCheckTests {
    func hop(
        _ origin: AssetModel.Id,
        _ destination: AssetModel.Id,
        amount: Balance,
        quote: Balance,
        verdict: AssetExchangeTradeLimitVerdict = .withinLimit
    ) -> AssetExchangeRouteItem {
        let edge = StubAssetExchangeEdge(
            origin: CommissionTestFixtures.asset(origin),
            destination: CommissionTestFixtures.asset(destination),
            type: .hydraSwap,
            chain: CommissionTestFixtures.chain,
            isRouted: true,
            verdict: verdict
        )

        return AssetExchangeRouteItem(edge: AnyAssetExchangeEdge(edge), amount: amount, quote: quote)
    }

    func makeRoute(_ items: [AssetExchangeRouteItem], direction: AssetConversion.Direction) -> AssetExchangeRoute {
        let amount = direction == .sell ? items.first?.amount : items.last?.amount

        return AssetExchangeRoute(items: items, amount: amount ?? 0, direction: direction)
    }

    static func depositsWrapper(
        for chainAssetIds: Set<ChainAssetId>
    ) -> CompoundOperationWrapper<[ChainAssetId: AssetBalanceExistence]> {
        .createWithResult(
            chainAssetIds.reduce(into: [:]) { result, chainAssetId in
                result[chainAssetId] = AssetBalanceExistence(
                    minBalance: existentialDeposits[chainAssetId.assetId] ?? 0,
                    isSelfSufficient: true
                )
            }
        )
    }

    func runCheck(
        _ route: AssetExchangeRoute,
        balanceExistenceWrapperFactory: SwapBalanceExistenceWrapperFactory = SwapPoolTradeLimitCheckTests.depositsWrapper
    ) throws -> SwapPoolTradeLimitCheck {
        let wrapper = route.poolTradeLimitCheckWrapper(
            slippage: .percent(of: 1),
            balanceExistenceWrapperFactory: balanceExistenceWrapperFactory
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
