import XCTest
@testable import novawallet
import Operation_iOS
import BigInt

final class AssetsExchangeRouteManagerTests: XCTestCase {
    func testBuyQuoteIsGrossedUpAtSwapSite() throws {
        let factory = AssetsExchangeOperationFactory(
            graph: CommissionTestFixtures.makeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])]),
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = factory.createQuoteWrapper(
            args: AssetConversion.QuoteArgs(
                assetIn: CommissionTestFixtures.asset(0),
                assetOut: CommissionTestFixtures.asset(1),
                amount: 1_000_000_000,
                direction: .buy
            ),
            grossingUpForCommission: true
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let quote = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(quote.route.amountOut, 1_008_572_870)
    }

    func testBuyQuoteIsNotGrossedUpWhenSuppressed() throws {
        let factory = AssetsExchangeOperationFactory(
            graph: CommissionTestFixtures.makeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])]),
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = factory.createQuoteWrapper(
            args: AssetConversion.QuoteArgs(
                assetIn: CommissionTestFixtures.asset(0),
                assetOut: CommissionTestFixtures.asset(1),
                amount: 1_000_000_000,
                direction: .buy
            ),
            grossingUpForCommission: false
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let quote = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(quote.route.amountOut, 1_000_000_000)
    }

    func testNonChargingPathIsNotGrossedUp() throws {
        let path = CommissionTestFixtures.createPath([.crossChain])

        let manager = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
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
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.amountIn, 1_000_000_000)
    }

    func testSellRoutePrefersHigherNetOutputOverHigherGrossOutput() throws {
        let route = try fetchSellRoute(hydraQuote: 101_000_000_000, assetHubQuote: 100_500_000_000)

        XCTAssertEqual(route.amountOut, 100_500_000_000)
    }

    func testSellRouteKeepsChargingPathWhenItStillWinsOnNetOutput() throws {
        let route = try fetchSellRoute(hydraQuote: 102_000_000_000, assetHubQuote: 100_500_000_000)

        XCTAssertEqual(route.amountOut, 102_000_000_000)
    }

    func testSellRouteRankingIsUnchangedWhenNoPathChargesCommission() throws {
        let route = try fetchSellRoute(
            hydraQuote: 101_000_000_000,
            assetHubQuote: 100_500_000_000,
            chargingEdgeType: .crossChain
        )

        XCTAssertEqual(route.amountOut, 101_000_000_000)
    }
}

private extension AssetsExchangeRouteManagerTests {
    func makeSingleEdgePath(type: AssetExchangeEdgeType, quote: Balance) -> AssetExchangeGraphPath {
        [
            AnyAssetExchangeEdge(
                StubAssetExchangeEdge(
                    origin: CommissionTestFixtures.asset(0),
                    destination: CommissionTestFixtures.asset(1),
                    type: type,
                    chain: CommissionTestFixtures.chain,
                    quoteClosure: { _, _ in quote }
                )
            )
        ]
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
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())
    }
}
