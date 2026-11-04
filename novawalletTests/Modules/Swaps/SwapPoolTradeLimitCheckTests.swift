import XCTest
@testable import novawallet
import Operation_iOS

final class SwapPoolTradeLimitCheckTests: XCTestCase {
    static let existentialDeposits: [AssetModel.Id: Balance] = [
        0: 588_235_294_118,
        1: 17_540_000,
        2: 1_000_000_000_000,
        3: 32_467_532_467_532_500,
        4: 34,
        5: 36
    ]

    static let hdxDeposit: Balance = 1_000_000_000_000

    func testRouterHopOutputBelowExistentialDepositBlocksTheRoute() throws {
        let route = makeRoute(
            [
                hop(0, 1, amount: 1_337_000_000_000_000, quote: 3_105_000_000),
                hop(1, 2, amount: 3_105_000_000, quote: 94_480_506_265)
            ],
            direction: .sell
        )

        XCTAssertEqual(
            try runCheck(route),
            .belowMinimum(failure(minimum: Self.hdxDeposit, direction: .sell, isUserInputAdjustable: false))
        )
    }

    func testSellAmountBelowExistentialDepositShowsTheLargerMinimum() throws {
        let belowDeposit = makeRoute([hop(2, 3, amount: 800_000_000_000, quote: 1_000_000)], direction: .sell)

        XCTAssertEqual(
            try runCheck(belowDeposit),
            .belowMinimum(failure(minimum: Self.hdxDeposit, direction: .sell, isUserInputAdjustable: true))
        )

        let belowBoth = makeRoute(
            [hop(4, 5, amount: 30, quote: 29, verdict: .belowMinimum(1000))],
            direction: .sell
        )

        XCTAssertEqual(
            try runCheck(belowBoth),
            .belowMinimum(failure(minimum: 1000, direction: .sell, isUserInputAdjustable: true))
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

    func testDirectHopIsExemptAndTheDepositItselfPasses() throws {
        let direct = makeRoute([hop(1, 2, amount: 20_000_000, quote: 1, isRouted: false)], direction: .sell)
        XCTAssertEqual(try runCheck(direct), .withinLimits)

        let atDeposit = makeRoute([hop(2, 1, amount: Self.hdxDeposit, quote: 20_000_000)], direction: .sell)
        XCTAssertEqual(try runCheck(atDeposit), .withinLimits)

        let belowDeposit = makeRoute([hop(2, 1, amount: Self.hdxDeposit - 1, quote: 20_000_000)], direction: .sell)
        XCTAssertEqual(
            try runCheck(belowDeposit),
            .belowMinimum(failure(minimum: Self.hdxDeposit, direction: .sell, isUserInputAdjustable: true))
        )
    }

    func testIntermediateHopOutputAtTheDepositPassesDespiteSlippage() throws {
        let route = makeRoute(
            [
                hop(0, 1, amount: 1_337_000_000_000_000, quote: 17_540_000),
                hop(1, 2, amount: 17_540_000, quote: 2_000_000_000_000)
            ],
            direction: .sell
        )

        XCTAssertEqual(try runCheck(route), .withinLimits)
    }

    func testFinalHopOutputAtTheDepositIsBlockedBySlippage() throws {
        let route = makeRoute(
            [
                hop(0, 1, amount: 1_337_000_000_000_000, quote: 3_105_000_000),
                hop(1, 2, amount: 3_105_000_000, quote: Self.hdxDeposit)
            ],
            direction: .sell
        )

        XCTAssertEqual(
            try runCheck(route),
            .belowMinimum(failure(minimum: Self.hdxDeposit, direction: .sell, isUserInputAdjustable: false))
        )
    }

    func testFailedExistentialDepositFetchAsksForRetry() throws {
        let route = makeRoute([hop(2, 1, amount: Self.hdxDeposit, quote: 20_000_000)], direction: .sell)

        let check = try runCheck(route) { _ in .createWithError(CommonError.noDataRetrieved) }

        XCTAssertEqual(check, .minBalanceUnavailable)
    }

    func testFailedExistentialDepositFetchStillReportsTheExceededPoolLimit() throws {
        let breach = AssetExchangeTradeLimitBreach(
            maxGivenAmount: 5_000_000_000_000,
            minTradingLimit: 1000,
            limitedAsset: CommissionTestFixtures.chainAsset(2)
        )

        let route = makeRoute(
            [hop(2, 1, amount: 10_000_000_000_000, quote: 20_000_000, verdict: .exceeds(breach))],
            direction: .sell
        )

        let check = try runCheck(route) { _ in .createWithError(CommonError.noDataRetrieved) }

        let expectedFailure = AssetExchangeTradeLimitFailure(
            limitedAsset: CommissionTestFixtures.chainAsset(2),
            maxGivenAmount: 5_000_000_000_000,
            minTradingLimit: 1000,
            direction: .sell,
            isUserInputAdjustable: true
        )

        XCTAssertEqual(check, .blocked(expectedFailure))
    }

    func testFailedExistentialDepositFetchStillReportsTheTradingMinimum() throws {
        let route = makeRoute(
            [hop(4, 5, amount: 306, quote: 305, verdict: .belowMinimum(1000))],
            direction: .sell
        )

        let check = try runCheck(route) { _ in .createWithError(CommonError.noDataRetrieved) }

        XCTAssertEqual(
            check,
            .belowMinimum(failure(minimum: 1000, direction: .sell, isUserInputAdjustable: true))
        )
    }
}

private extension SwapPoolTradeLimitCheckTests {
    func hop(
        _ origin: AssetModel.Id,
        _ destination: AssetModel.Id,
        amount: Balance,
        quote: Balance,
        isRouted: Bool = true,
        verdict: AssetExchangeTradeLimitVerdict = .withinLimit
    ) -> AssetExchangeRouteItem {
        let edge = StubAssetExchangeEdge(
            origin: CommissionTestFixtures.asset(origin),
            destination: CommissionTestFixtures.asset(destination),
            type: .hydraSwap,
            chain: CommissionTestFixtures.chain,
            isRouted: isRouted,
            verdict: verdict
        )

        return AssetExchangeRouteItem(edge: AnyAssetExchangeEdge(edge), amount: amount, quote: quote)
    }

    func makeRoute(_ items: [AssetExchangeRouteItem], direction: AssetConversion.Direction) -> AssetExchangeRoute {
        let amount = direction == .sell ? items.first?.amount : items.last?.amount

        return AssetExchangeRoute(items: items, amount: amount ?? 0, direction: direction)
    }

    func failure(
        minimum: Balance,
        direction: AssetConversion.Direction,
        isUserInputAdjustable: Bool
    ) -> AssetExchangeTradeMinimumFailure {
        AssetExchangeTradeMinimumFailure(
            minimumAmount: minimum,
            direction: direction,
            isUserInputAdjustable: isUserInputAdjustable
        )
    }

    static func depositsWrapper(
        for chainAssetIds: Set<ChainAssetId>
    ) -> CompoundOperationWrapper<[ChainAssetId: AssetBalanceExistence]> {
        let existences = chainAssetIds.reduce(into: [ChainAssetId: AssetBalanceExistence]()) { result, assetId in
            result[assetId] = AssetBalanceExistence(
                minBalance: existentialDeposits[assetId.assetId] ?? 0,
                isSelfSufficient: true
            )
        }

        return .createWithResult(existences)
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
