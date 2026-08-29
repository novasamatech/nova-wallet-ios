import XCTest
@testable import novawallet
import Operation_iOS
import BigInt

final class AssetsExchangeRouteManagerTests: XCTestCase {
    func testBuyQuoteIsGrossedUpAtSwapSite() throws {
        let factory = AssetsExchangeOperationFactory(
            graph: CommissionTestFixtures.makeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])]),
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = factory.createQuoteWrapper(
            args: AssetConversion.QuoteArgs(
                assetIn: CommissionTestFixtures.asset(0),
                assetOut: CommissionTestFixtures.asset(1),
                amount: 1_000_000_000,
                direction: .buy
            )
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let quote = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(quote.route.amountOut, 1_008_500_000)
    }

    func testNonChargingPathIsNotGrossedUp() throws {
        let path = CommissionTestFixtures.createPath([.crossChain])

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.amountOut, 1_000_000_000)
    }

    func testSellQuoteIsNeverGrossedUp() throws {
        let path = CommissionTestFixtures.createPath([.hydraSwap])

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.amountIn, 1_000_000_000)
    }

    func testSellRouteRanksOnGrossOutputIgnoringCommission() throws {
        let route = try fetchSellRoute(hydraQuote: 101_000_000_000, assetHubQuote: 100_500_000_000)

        XCTAssertEqual(route.amountOut, 101_000_000_000)

        let gross: Balance = 101_000_000_000
        let netOfWinner = gross - AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: gross)

        XCTAssertLessThan(netOfWinner, 100_500_000_000)
    }

    func testSellRouteRankingIsUnchangedWhenNoPathChargesCommission() throws {
        let route = try fetchSellRoute(
            hydraQuote: 101_000_000_000,
            assetHubQuote: 100_500_000_000,
            chargingEdgeType: .crossChain
        )

        XCTAssertEqual(route.amountOut, 101_000_000_000)
    }

    func testBuyRouteRanksOnRawAmountIgnoringCommission() throws {
        let route = try fetchBuyRoute(hydraAmountIn: 100_000_000_000, assetHubAmountIn: 100_600_000_000)

        XCTAssertEqual(route.items.first?.edge.type, .hydraSwap)
        XCTAssertEqual(route.amountIn, 100_850_000_000)
    }

    func testBuyWinnerIsRequotedGrossedUp() throws {
        let route = try fetchBuyRoute(hydraAmountIn: 100_000_000_000, assetHubAmountIn: 100_600_000_000)

        XCTAssertEqual(route.amountOut, 1_008_500_000)
    }

    func testOverLimitCandidateIsDroppedAndTheWorkingAlternativeWins() throws {
        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { _, _ in
                    throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                },
                makeSingleEdgePath(type: .assetHubSwap, quote: 900_000_000)
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.items.first?.edge.type, .assetHubSwap)
        XCTAssertEqual(route.amountOut, 900_000_000)
    }

    func testAllCandidatesOverLimitYieldNoRouteRatherThanFailingTheSearch() throws {
        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { _, _ in
                    throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                },
                makeSingleEdgePath(type: .assetHubSwap) { _, _ in
                    throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertNil(try wrapper.targetOperation.extractNoCancellableResultData())
    }

    func testBuyWinnerFallsBackToTheUngrossedRouteWhenTheGrossedUpRequoteIsOverLimit() throws {
        let amountOut: Balance = 1_000_000_000
        let amountIn: Balance = 100_000_000_000

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { amount, _ in
                    guard amount == amountOut else {
                        throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                    }

                    return amountIn
                }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: amountOut, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.amountOut, amountOut)
        XCTAssertEqual(route.amountIn, amountIn)
    }

    func testBuyWinnerSurfacesANonLimitFailureOfTheGrossedUpRequote() {
        let amountOut: Balance = 1_000_000_000

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { amount, _ in
                    guard amount == amountOut else {
                        throw StubAssetExchangeEdgeError.notSupported
                    }

                    return 100_000_000_000
                }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: amountOut, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case StubAssetExchangeEdgeError.notSupported = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testBuyFallbackRouteStillPaysCommissionAndSoNetsLessThanRequested() throws {
        let amountOut: Balance = 1_000_000_000
        let policy = CommissionTestFixtures.createPolicy()

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { amount, _ in
                    guard amount == amountOut else {
                        throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                    }

                    return 100_000_000_000
                }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: amountOut, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())
        let commission = try XCTUnwrap(policy.resolveCommission(for: route))

        XCTAssertEqual(commission.amount, policy.rateOfGross.mul(value: amountOut))
        XCTAssertLessThan(route.amountOut.subtractOrZero(commission.amount), amountOut)
    }

    func testNonChargingBuyWinnerIsQuotedOnce() throws {
        let counter = QuoteCallCounter()

        let path = makeSingleEdgePath(type: .assetHubSwap) { amount, _ in
            counter.increment()
            return amount
        }

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(counter.count, 1)
    }
}

private extension AssetsExchangeRouteManagerTests {
    func makeSingleEdgePath(
        type: AssetExchangeEdgeType,
        quoteClosure: @escaping (Balance, AssetConversion.Direction) throws -> Balance
    ) -> AssetExchangeGraphPath {
        [
            AnyAssetExchangeEdge(
                StubAssetExchangeEdge(
                    origin: CommissionTestFixtures.asset(0),
                    destination: CommissionTestFixtures.asset(1),
                    type: type,
                    chain: CommissionTestFixtures.chain,
                    quoteClosure: quoteClosure
                )
            )
        ]
    }

    func makeSingleEdgePath(type: AssetExchangeEdgeType, quote: Balance) -> AssetExchangeGraphPath {
        makeSingleEdgePath(type: type) { _, _ in quote }
    }

    func fetchSellRoute(
        hydraQuote: Balance,
        assetHubQuote: Balance,
        chargingEdgeType: AssetExchangeEdgeType = .hydraSwap
    ) throws -> AssetExchangeRoute {
        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: chargingEdgeType, quote: hydraQuote),
                makeSingleEdgePath(type: .assetHubSwap, quote: assetHubQuote)
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())
    }

    func fetchBuyRoute(hydraAmountIn: Balance, assetHubAmountIn: Balance) throws -> AssetExchangeRoute {
        let amountOut: Balance = 1_000_000_000

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * hydraAmountIn / amountOut },
                makeSingleEdgePath(type: .assetHubSwap) { amount, _ in amount * assetHubAmountIn / amountOut }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: amountOut, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())
    }
}

private final class QuoteCallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
