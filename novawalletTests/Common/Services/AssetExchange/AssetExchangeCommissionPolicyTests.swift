import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import Cuckoo

final class AssetExchangeCommissionPolicyTests: XCTestCase {
    func testChargingIndexForRouteShapes() throws {
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertEqual(
            try chargingOperationIndex(using: policy, edgeTypes: [.crossChain, .hydraSwap, .crossChain]),
            1
        )
        XCTAssertEqual(
            try chargingOperationIndex(using: policy, edgeTypes: [.hydraSwap, .crossChain, .assetHubSwap]),
            0
        )
        XCTAssertEqual(
            try chargingOperationIndex(using: policy, edgeTypes: [.hydraSwap, .hydraSwap, .crossChain, .hydraSwap]),
            2
        )
        XCTAssertEqual(
            try chargingOperationIndex(
                using: policy,
                edgeTypes: [.hydraSwap, .hydraSwap, .crossChain, .assetHubSwap, .crossChain, .hydraSwap]
            ),
            4
        )
        XCTAssertEqual(
            try chargingOperationIndex(using: policy, edgeTypes: [.hydraSwap, .hydraSwap]),
            0
        )
    }

    func testChargingIndexMatchesStubAtomicGrouping() throws {
        try assertChargingIndexMatchesAtomicGrouping(
            edgeTypes: [.hydraSwap, .hydraSwap, .crossChain, .hydraSwap],
            expectedOperationCount: 3,
            expectedChargingIndex: 2,
            expectedChargedAssetId: 4
        )

        try assertChargingIndexMatchesAtomicGrouping(
            edgeTypes: [.hydraSwap, .hydraSwap, .crossChain, .assetHubSwap, .crossChain, .hydraSwap],
            expectedOperationCount: 5,
            expectedChargingIndex: 4,
            expectedChargedAssetId: 6
        )
    }

    func testNoChargeWithoutHydraEdge() throws {
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertNil(try chargingOperationIndex(using: policy, edgeTypes: [.crossChain, .crossChain]))
        XCTAssertNil(try chargingOperationIndex(using: policy, edgeTypes: [.assetHubSwap, .crossChain]))
        XCTAssertNil(try chargingOperationIndex(using: policy, edgeTypes: []))
    }

    func testEstimatedAmountIsRateOfChargingSegmentOutput() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertEqual(commission?.estimatedAmount, 8428)
        XCTAssertEqual(
            commission?.estimatedAmount,
            AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: 1_000_000)
        )
    }

    func testBaseComesFromLastEdgeOfRun() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap, .hydraSwap], amounts: [1_000_000, 7_000_000])

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertEqual(commission?.asset, CommissionTestFixtures.asset(2))
        XCTAssertEqual(commission?.estimatedAmount, 58998)
    }

    func testBeneficiaryDecodesToConfiguredAccount() throws {
        let expectedBeneficiary = try AssetExchangeCommissionConstants.hydrationBeneficiaryAddress.toAccountId()
        XCTAssertEqual(expectedBeneficiary.count, 32)

        XCTAssertEqual(
            expectedBeneficiary.toHex(),
            "035ff76d86ca67ef0499f8597101aab0e6ad894a805cd93a51409bd6d71a8841"
        )

        let policy = AssetExchangeCommissionPolicyFactory.createHydrationPolicy(
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [CommissionTestFixtures.chain]),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        let concretePolicy = try XCTUnwrap(policy as? AssetExchangeCommissionPolicy)
        XCTAssertEqual(concretePolicy.beneficiary, expectedBeneficiary)
    }

    func testCommissionCarriesConfiguredBeneficiary() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000_000)

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertEqual(commission?.estimatedAmount, 8_428_358)
        XCTAssertEqual(commission?.beneficiary, CommissionTestFixtures.beneficiary)
    }

    func testChargesOnlyWhenBeneficiaryIsEstablished() throws {
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let established = CommissionTestFixtures.createPolicy(
            beneficiaryProvider: CommissionTestFixtures.stubBeneficiaryProvider(canReceive: true)
        )

        XCTAssertNotNil(try resolveCommission(using: established, route: route))

        let unestablished = CommissionTestFixtures.createPolicy(
            beneficiaryProvider: CommissionTestFixtures.stubBeneficiaryProvider(canReceive: false)
        )

        XCTAssertNil(try resolveCommission(using: unestablished, route: route))
    }

    func testReadinessFailureForgoesCommission() throws {
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let failing = CommissionTestFixtures.createPolicy(
            beneficiaryProvider: CommissionTestFixtures.failingBeneficiaryProvider()
        )

        XCTAssertNil(try resolveCommission(using: failing, route: route))
    }

    func testSkipsForZeroAmount() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 117)

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertNil(commission)
    }

    func testGrossUpIsCeilingAndPathScoped() throws {
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertEqual(
            try grossingUpAmountOut(using: policy, 1_000_000_000, for: CommissionTestFixtures.createPath([.hydraSwap])),
            1_008_500_000
        )
        XCTAssertEqual(
            try grossingUpAmountOut(using: policy, 1_000_000_000, for: CommissionTestFixtures.createPath([.crossChain])),
            1_000_000_000
        )
    }

    func testGrossUpIsSkippedWhenBeneficiaryIsNotEstablished() throws {
        let policy = CommissionTestFixtures.createPolicy(
            beneficiaryProvider: CommissionTestFixtures.stubBeneficiaryProvider(canReceive: false)
        )

        XCTAssertEqual(
            try grossingUpAmountOut(using: policy, 1_000_000_000, for: CommissionTestFixtures.createPath([.hydraSwap])),
            1_000_000_000
        )
    }

    func testBuyGrossUpRoundTripsExactly() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let path = CommissionTestFixtures.createPath([.hydraSwap])

        let targets: [Balance] = [1, 2, 117, 118, 999, 1_000_000_000, 123_456_789_012_345]

        for target in targets {
            let gross = try grossingUpAmountOut(using: policy, target, for: path)
            let net = gross - AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: gross)

            XCTAssertEqual(net, target)
        }
    }

    func testCommissionIndexOutsideOperationRangeThrows() throws {
        let route = CommissionTestFixtures.createRoute([.hydraSwap, .hydraSwap], amount: 1_000_000)

        let commission = AssetExchangeCommission(
            chargingOperationIndex: 5,
            asset: CommissionTestFixtures.asset(2),
            estimatedAmount: 1,
            minimumChargeableAmount: 0,
            beneficiary: CommissionTestFixtures.beneficiary,
            rateOfGross: AssetExchangeCommissionConstants.rate.asShareOfGross
        )

        XCTAssertThrowsError(
            try CommissionTestFixtures.makeFactory().prepareAtomicOperations(
                for: route,
                slippage: BigRational(numerator: 0, denominator: 100),
                feeAssetId: CommissionTestFixtures.asset(0),
                commission: commission
            )
        ) { error in
            guard case AssetsExchangeOperationFactoryError.commissionNotAttached = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }
}

private extension AssetExchangeCommissionPolicyTests {
    func resolveCommission(
        using policy: AssetExchangeCommissionPolicyProtocol,
        route: AssetExchangeRoute
    ) throws -> AssetExchangeCommission? {
        let wrapper = policy.resolveCommissionWrapper(for: route)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func chargingOperationIndex(
        using policy: AssetExchangeCommissionPolicyProtocol,
        edgeTypes: [AssetExchangeEdgeType]
    ) throws -> Int? {
        let route = CommissionTestFixtures.createRoute(edgeTypes, amount: 1_000_000)

        return try resolveCommission(using: policy, route: route)?.chargingOperationIndex
    }

    func grossingUpAmountOut(
        using policy: AssetExchangeCommissionPolicyProtocol,
        _ netAmountOut: Balance,
        for path: AssetExchangeGraphPath
    ) throws -> Balance {
        let wrapper = policy.grossingUpAmountOutWrapper(netAmountOut, for: path)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func assertChargingIndexMatchesAtomicGrouping(
        edgeTypes: [AssetExchangeEdgeType],
        expectedOperationCount: Int,
        expectedChargingIndex: Int,
        expectedChargedAssetId: AssetModel.Id
    ) throws {
        let route = CommissionTestFixtures.createRoute(edgeTypes, amount: 1_000_000)

        let policy = CommissionTestFixtures.createPolicy()
        let commission = try XCTUnwrap(resolveCommission(using: policy, route: route))

        XCTAssertEqual(commission.asset, CommissionTestFixtures.asset(expectedChargedAssetId))

        let factory = CommissionTestFixtures.makeFactory()

        let operations = try factory.prepareAtomicOperations(
            for: route,
            slippage: BigRational(numerator: 0, denominator: 100),
            feeAssetId: CommissionTestFixtures.asset(0),
            commission: commission
        )

        XCTAssertEqual(operations.count, expectedOperationCount)

        let chargingIndices = operations.enumerated().compactMap { index, operation -> Int? in
            (operation as? StubAtomicOperation)?.args.commission != nil ? index : nil
        }

        XCTAssertEqual(chargingIndices, [expectedChargingIndex])

        let chargingOperation = try XCTUnwrap(operations[expectedChargingIndex] as? StubAtomicOperation)
        XCTAssertEqual(chargingOperation.edges.last?.destination, CommissionTestFixtures.asset(expectedChargedAssetId))
    }
}
