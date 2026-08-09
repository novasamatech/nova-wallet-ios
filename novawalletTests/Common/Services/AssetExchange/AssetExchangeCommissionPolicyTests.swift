import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import Cuckoo

final class AssetExchangeCommissionPolicyTests: XCTestCase {
    func testChargingIndexForRouteShapes() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy

        XCTAssertEqual(
            policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.crossChain, .hydraSwap, .crossChain])),
            1
        )
        XCTAssertEqual(
            policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.hydraSwap, .crossChain, .assetHubSwap])),
            0
        )
        XCTAssertEqual(
            policy.chargingOperationIndex(
                in: CommissionTestFixtures.createPath([.hydraSwap, .hydraSwap, .crossChain, .hydraSwap])
            ),
            2
        )
        XCTAssertEqual(
            policy.chargingOperationIndex(
                in: CommissionTestFixtures.createPath(
                    [.hydraSwap, .hydraSwap, .crossChain, .assetHubSwap, .crossChain, .hydraSwap]
                )
            ),
            4
        )
        XCTAssertEqual(
            policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.hydraSwap, .hydraSwap])),
            0
        )
    }

    func testChargingIndexMatchesAtomicGrouping() throws {
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

    func testNoChargeWithoutHydraEdge() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy

        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.crossChain, .crossChain])))
        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.assetHubSwap, .crossChain])))
        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([])))
    }

    /// The fee-time estimate is the rate applied to the charging segment's undiscounted output —
    /// the same quantity `HydraExchangeExtrinsicParamsFactory.commissionAmount` charges and the
    /// display nets, so estimate, disclosure and transfer cannot drift apart.
    func testEstimatedAmountIsRateOfChargingSegmentOutput() throws {
        let policyUnderTest = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1)
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        let commission = try resolveCommission(using: policyUnderTest.policy, route: route)

        XCTAssertEqual(commission?.estimatedAmount, 8500)
        XCTAssertEqual(
            commission?.estimatedAmount,
            AssetExchangeCommissionConstants.rate.mul(value: 1_000_000)
        )
    }

    func testBaseComesFromLastEdgeOfRun() throws {
        let policyUnderTest = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1)
        let route = CommissionTestFixtures.createRoute([.hydraSwap, .hydraSwap], amounts: [1_000_000, 7_000_000])

        let commission = try resolveCommission(using: policyUnderTest.policy, route: route)

        XCTAssertEqual(commission?.asset, CommissionTestFixtures.asset(2))
        XCTAssertEqual(commission?.estimatedAmount, 59500)
    }

    func testBeneficiaryDecodesToConfiguredAccount() throws {
        let expectedBeneficiary = try AssetExchangeCommissionConstants.hydrationBeneficiaryAddress.toAccountId()
        XCTAssertEqual(expectedBeneficiary.count, 32)

        // Same account the Android client pays to (NovaSwapCommission.FEE_ACCOUNT_HEX). A typo in
        // the SS58 constant makes the factory fall back to AssetExchangeNoCommissionPolicy and
        // revenue silently stops, so pin the decoded bytes rather than just the length.
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

    func testSkipsWhenBeneficiaryBelowExistentialDeposit() throws {
        let belowDeposit = CommissionTestFixtures.createPolicy(beneficiaryFree: 0, minBalance: 1_000_000)
        let poorRoute = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000_000)

        XCTAssertNil(try resolveCommission(using: belowDeposit.policy, route: poorRoute))

        let atDeposit = CommissionTestFixtures.createPolicy(beneficiaryFree: 1_000_000, minBalance: 1_000_000)
        let tinyRoute = CommissionTestFixtures.createRoute([.hydraSwap], amount: 200)

        let commission = try resolveCommission(using: atDeposit.policy, route: tinyRoute)

        XCTAssertEqual(commission?.estimatedAmount, 1)
    }

    func testSkipsForZeroAmount() throws {
        let policyUnderTest = CommissionTestFixtures.createPolicy(beneficiaryFree: 5, minBalance: 5)
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 117)

        let commission = try resolveCommission(using: policyUnderTest.policy, route: route)

        XCTAssertNil(commission)
        XCTAssertEqual(policyUnderTest.balanceQueryFactory.callCount, 0)
        XCTAssertEqual(policyUnderTest.storageInfoFactory.depositCallCount, 0)
    }

    func testSkipsForEvmChargedAsset() throws {
        let policyUnderTest = CommissionTestFixtures.createPolicy(
            beneficiaryFree: 10,
            minBalance: 1,
            storageInfoResult: .success(.evmNative)
        )
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000_000)

        XCTAssertNil(try resolveCommission(using: policyUnderTest.policy, route: route))
    }

    func testGrossUpIsCeilingAndPathScoped() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy

        XCTAssertEqual(
            policy.grossingUpAmountOut(1_000_000_000, for: CommissionTestFixtures.createPath([.hydraSwap])),
            1_008_572_870
        )
        XCTAssertEqual(
            policy.grossingUpAmountOut(1_000_000_000, for: CommissionTestFixtures.createPath([.crossChain])),
            1_000_000_000
        )
    }

    func testBuyGrossUpBoundedByOnePlank() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let path = CommissionTestFixtures.createPath([.hydraSwap])

        let targets: [Balance] = [1, 2, 117, 118, 999, 1_000_000_000, 123_456_789_012_345]

        for target in targets {
            let gross = policy.grossingUpAmountOut(target, for: path)
            let net = policy.netAmount(from: gross, willCharge: true)

            XCTAssertGreaterThanOrEqual(net, target)
            XCTAssertLessThanOrEqual(net, target + 1)
        }
    }

    func testNetAmountAppliesRateNotAbsoluteAmount() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy

        XCTAssertEqual(policy.netAmount(from: 1_000_000, willCharge: true), 991_500)
        XCTAssertEqual(policy.netAmount(from: 1_000_000, willCharge: false), 1_000_000)
    }

    func testArithmeticAtExtremes() {
        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let path = CommissionTestFixtures.createPath([.hydraSwap])

        XCTAssertEqual(policy.netAmount(from: 0, willCharge: true), 0)
        XCTAssertEqual(policy.netAmount(from: 1, willCharge: true), 1)

        let huge = Balance(UInt64.max) * Balance(UInt64.max)

        let netHuge = policy.netAmount(from: huge, willCharge: true)
        let grossHuge = policy.grossingUpAmountOut(huge, for: path)

        XCTAssertLessThan(netHuge, huge)
        XCTAssertGreaterThan(grossHuge, huge)

        XCTAssertEqual(policy.grossingUpAmountOut(0, for: path), 0)
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

    func assertChargingIndexMatchesAtomicGrouping(
        edgeTypes: [AssetExchangeEdgeType],
        expectedOperationCount: Int,
        expectedChargingIndex: Int,
        expectedChargedAssetId: AssetModel.Id
    ) throws {
        let route = CommissionTestFixtures.createRoute(edgeTypes, amount: 1_000_000)
        let path = route.items.map(\.edge)

        let policy = CommissionTestFixtures.createPolicy(beneficiaryFree: 10, minBalance: 1).policy
        let chargingOperationIndex = try XCTUnwrap(policy.chargingOperationIndex(in: path))

        let commission = AssetExchangeCommission(
            chargingOperationIndex: chargingOperationIndex,
            asset: CommissionTestFixtures.asset(expectedChargedAssetId),
            estimatedAmount: 1,
            beneficiary: CommissionTestFixtures.beneficiary,
            rate: AssetExchangeCommissionConstants.rate
        )

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
