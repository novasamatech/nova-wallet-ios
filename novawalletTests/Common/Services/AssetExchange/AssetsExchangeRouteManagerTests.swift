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

    func testSellWinnerIsTheFirstOfEquallyRankedCandidates() throws {
        let firstPath = makeSingleEdgePath(type: .hydraSwap, quote: 101_000_000_000)
        let secondPath = makeSingleEdgePath(type: .assetHubSwap, quote: 101_000_000_000)

        let route = try XCTUnwrap(
            try fetchRoute(paths: [firstPath, secondPath], amount: 1_000_000_000, direction: .sell)
        )

        XCTAssertEqual(route.items.first?.edge.identifier, firstPath.first?.identifier)
    }

    func testBuyRouteRanksOnRawAmountIgnoringCommission() throws {
        let route = try fetchBuyRoute(hydraAmountIn: 100_000_000_000, assetHubAmountIn: 100_600_000_000)

        XCTAssertEqual(route.items.first?.edge.type, .hydraSwap)
        XCTAssertEqual(route.amountIn, 100_850_000_000)
    }

    func testBuyWinnerIsTheFirstOfEquallyRankedCandidates() throws {
        let firstPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * 100 }
        let secondPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * 100 }

        let route = try XCTUnwrap(
            try fetchRoute(paths: [firstPath, secondPath], amount: 1_000_000_000, direction: .buy)
        )

        XCTAssertEqual(route.items.first?.edge.identifier, firstPath.first?.identifier)
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

    func testBuyWinnerYieldsNoRouteWhenTheUngrossedFallbackWouldStillBeChargedCommission() throws {
        XCTAssertNil(try fetchBuyRouteRejectingTheGrossedUpRequote(amountOut: 1_000_000_000))
    }

    func testBuyWinnerFallsBackToTheUngrossedRouteWhenNoCommissionIsChargeableOnIt() throws {
        let amountOut: Balance = 118

        let route = try XCTUnwrap(try fetchBuyRouteRejectingTheGrossedUpRequote(amountOut: amountOut))

        XCTAssertNil(CommissionTestFixtures.createPolicy().resolveCommission(for: route))
        XCTAssertEqual(route.amountOut, amountOut)
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

    func testBuyWalkFallsThroughToTheRunnerUpWhenTheWinnersGrossUpIsLimited() throws {
        let amountOut: Balance = 1_000_000_000

        let winnerPath = makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 100_000_000_000)
        let runnerUpPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * 101 }

        let route = try XCTUnwrap(
            try fetchRoute(paths: [winnerPath, runnerUpPath], amount: amountOut, direction: .buy)
        )

        XCTAssertEqual(route.items.first?.edge.identifier, runnerUpPath.first?.identifier)
        XCTAssertEqual(route.amountOut, 1_008_500_000)
        XCTAssertEqual(route.amountIn, 101_858_500_000)
    }

    func testBuyWalkAdvancesPastEveryLimitedCandidateToTheFirstServingOne() throws {
        let amountOut: Balance = 1_000_000_000

        let firstLimitedPath = makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 100_000_000_000)
        let secondLimitedPath = makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 100_500_000_000)
        let servingPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * 101 }

        let route = try XCTUnwrap(
            try fetchRoute(
                paths: [firstLimitedPath, secondLimitedPath, servingPath],
                amount: amountOut,
                direction: .buy
            )
        )

        XCTAssertEqual(route.items.first?.edge.identifier, servingPath.first?.identifier)
        XCTAssertEqual(route.amountOut, 1_008_500_000)
        XCTAssertEqual(route.amountIn, 101_858_500_000)
    }

    func testBuyWalkYieldsNoRouteWhenEveryCandidatesGrossUpIsLimited() throws {
        let amountOut: Balance = 1_000_000_000

        let paths = [
            makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 100_000_000_000),
            makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 100_500_000_000),
            makeLimitedGrossUpPath(servingAmountOut: amountOut, amountIn: 101_000_000_000)
        ]

        XCTAssertNil(try fetchRoute(paths: paths, amount: amountOut, direction: .buy))
    }

    func testBuyWalkStopsAtANonLimitFailureInsteadOfTryingTheRunnerUp() {
        let amountOut: Balance = 1_000_000_000

        let failingPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in
            guard amount == amountOut else {
                throw StubAssetExchangeEdgeError.notSupported
            }

            return 100_000_000_000
        }

        let runnerUpPath = makeSingleEdgePath(type: .hydraSwap) { amount, _ in amount * 101 }

        XCTAssertThrowsError(
            try fetchRoute(paths: [failingPath, runnerUpPath], amount: amountOut, direction: .buy)
        ) { error in
            guard case StubAssetExchangeEdgeError.notSupported = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
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

    func makeLimitedGrossUpPath(servingAmountOut: Balance, amountIn: Balance) -> AssetExchangeGraphPath {
        makeSingleEdgePath(type: .hydraSwap) { amount, _ in
            guard amount == servingAmountOut else {
                throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
            }

            return amountIn
        }
    }

    func makeManager(paths: [AssetExchangeGraphPath]) -> AssetsExchangeRouteManager {
        AssetsExchangeRouteManager(
            possiblePaths: paths,
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    func fetchRoute(
        paths: [AssetExchangeGraphPath],
        amount: Balance,
        direction: AssetConversion.Direction
    ) throws -> AssetExchangeRoute? {
        let manager = makeManager(paths: paths)

        let wrapper = manager.fetchRoute(for: amount, direction: direction)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func fetchBuyRouteRejectingTheGrossedUpRequote(amountOut: Balance) throws -> AssetExchangeRoute? {
        let manager = AssetsExchangeRouteManager(
            possiblePaths: [
                makeSingleEdgePath(type: .hydraSwap) { amount, _ in
                    guard amount == amountOut else {
                        throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit
                    }

                    return amount * 100
                }
            ],
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: amountOut, direction: .buy)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
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
