import XCTest
@testable import novawallet
import Operation_iOS
import BigInt

final class AssetsExchangeRouteManagerTests: XCTestCase {
    func testBuyQuoteIsGrossedUpAtSwapSite() throws {
        let factory = AssetsExchangeOperationFactory(
            graph: StubExchangeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])]),
            pathCostEstimator: StubExchangePathCostEstimator(),
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
            graph: StubExchangeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])]),
            pathCostEstimator: StubExchangePathCostEstimator(),
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
            pathCostEstimator: StubExchangePathCostEstimator(),
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
            pathCostEstimator: StubExchangePathCostEstimator(),
            commissionPolicy: CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let wrapper = manager.fetchRoute(for: 1_000_000_000, direction: .sell)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let route = try XCTUnwrap(try wrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(route.amountIn, 1_000_000_000)
    }

    func testGrossUpAddsNoOperations() {
        let path = CommissionTestFixtures.createPath([.hydraSwap])
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy

        let managerWithPolicy = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: StubExchangePathCostEstimator(),
            commissionPolicy: policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let managerWithoutPolicy = AssetsExchangeRouteManager(
            possiblePaths: [path],
            pathCostEstimator: StubExchangePathCostEstimator(),
            commissionPolicy: nil,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let withPolicyWrapper = managerWithPolicy.createQuote(for: path, amount: 1_000_000_000, direction: .buy)
        let withoutPolicyWrapper = managerWithoutPolicy.createQuote(for: path, amount: 1_000_000_000, direction: .buy)

        XCTAssertEqual(withPolicyWrapper.allOperations.count, withoutPolicyWrapper.allOperations.count)
    }

    func testExecutionReusesFeeCommission() {
        let (factory, countingPolicy) = makeCountingFactory()
        let fee = makeChargingFee()

        let executionWrapper = factory.createExecutionWrapper(
            for: fee,
            notifyingIn: .main,
            operationStartClosure: { _ in }
        )
        OperationQueue().addOperations(executionWrapper.allOperations, waitUntilFinished: true)

        let submitWrapper = factory.createSingleOperationSubmitWrapper(for: fee)
        OperationQueue().addOperations(submitWrapper.allOperations, waitUntilFinished: true)

        XCTAssertEqual(countingPolicy.resolveCallCount, 0)
    }

    func testFeeResolvesCommissionExactlyOnce() {
        let (factory, countingPolicy) = makeCountingFactory()

        let args = AssetExchangeFeeArgs(
            route: CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000),
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0)
        )

        let feeWrapper = factory.createFeeWrapper(for: args)
        OperationQueue().addOperations(feeWrapper.allOperations, waitUntilFinished: true)

        XCTAssertEqual(countingPolicy.resolveCallCount, 1)
    }

    func testDecisionFrozenAmountDerived() throws {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let resolveWrapper = policy.resolveCommissionWrapper(
            for: route,
            slippage: BigRational(numerator: 0, denominator: 100)
        )
        OperationQueue().addOperations(resolveWrapper.allOperations, waitUntilFinished: true)

        let commission = try XCTUnwrap(try resolveWrapper.targetOperation.extractNoCancellableResultData())

        XCTAssertEqual(commission.estimatedAmount, 8500)

        let correctedLimit = AssetExchangeSwapLimit(
            direction: .sell,
            amountIn: 1_000_000,
            amountOut: 1_000_000,
            slippage: BigRational(numerator: 0, denominator: 100)
        ).replacingAmountIn(500_000, shouldReplaceBuyWithSell: false)

        let callArgs = CommissionTestFixtures.makeCallArgs(
            direction: correctedLimit.direction,
            amountIn: correctedLimit.amountIn,
            amountOut: correctedLimit.amountOut,
            slippage: correctedLimit.slippage
        )

        let derivedAmount = HydraExchangeExtrinsicParamsFactory.commissionAmount(for: commission, callArgs: callArgs)

        XCTAssertEqual(derivedAmount, 4250)
        XCTAssertNotEqual(derivedAmount, commission.estimatedAmount)
    }
}

private extension AssetsExchangeRouteManagerTests {
    func makeCountingFactory() -> (AssetsExchangeOperationFactory, CountingCommissionPolicy) {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let countingPolicy = CountingCommissionPolicy(wrapped: policy)

        let factory = AssetsExchangeOperationFactory(
            graph: StubExchangeGraph(paths: []),
            pathCostEstimator: StubExchangePathCostEstimator(),
            commissionPolicy: countingPolicy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        return (factory, countingPolicy)
    }

    func makeChargingFee() -> AssetExchangeFee {
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let commission = AssetExchangeCommission(
            chargingOperationIndex: 0,
            asset: CommissionTestFixtures.asset(1),
            estimatedAmount: 8500,
            beneficiary: CommissionTestFixtures.beneficiary,
            rate: AssetExchangeCommissionConstants.rate
        )

        return AssetExchangeFee(
            route: route,
            operationFees: [],
            intermediateFeesInAssetIn: 0,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )
    }
}
