import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import Cuckoo

final class AssetExchangeCommissionPolicyTests: XCTestCase {
    func testChargingIndexForRouteShapes() {
        let policy = CommissionTestFixtures.createPolicy()

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
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.crossChain, .crossChain])))
        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([.assetHubSwap, .crossChain])))
        XCTAssertNil(policy.chargingOperationIndex(in: CommissionTestFixtures.createPath([])))
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
            logger: Logger.shared
        )

        let concretePolicy = try XCTUnwrap(policy as? AssetExchangeCommissionPolicy)
        XCTAssertEqual(concretePolicy.beneficiary, expectedBeneficiary)
    }

    func testChargesRegardlessOfBeneficiaryBalance() throws {
        // Nova controls the beneficiary account, so there is no balance/ED precondition: the decision
        // depends on the route alone and cannot differ between quote time and submission time.
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000_000)

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertEqual(commission?.estimatedAmount, 8_428_358)
        XCTAssertEqual(commission?.beneficiary, CommissionTestFixtures.beneficiary)
    }

    func testSkipsWhenCommissionWouldLandBelowTheChargedAssetExistentialDeposit() throws {
        // The commission transfer shares an atomic batch with the swap, so a sub-ED deposit to a
        // beneficiary account that does not exist yet would revert the user's swap. Forgo it instead.
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)
        let expectedAmount = AssetExchangeCommissionConstants.rate.asShareOfGross.mul(value: 1_000_000)

        XCTAssertEqual(expectedAmount, 8428)

        let blocked = CommissionTestFixtures.createPolicy(
            chainRegistry: MockChainRegistryProtocol().applyDefault(
                for: [CommissionTestFixtures.chain(withOrmlExistentialDeposit: expectedAmount + 1)]
            )
        )

        XCTAssertNil(try resolveCommission(using: blocked, route: route))

        let allowed = CommissionTestFixtures.createPolicy(
            chainRegistry: MockChainRegistryProtocol().applyDefault(
                for: [CommissionTestFixtures.chain(withOrmlExistentialDeposit: expectedAmount)]
            )
        )

        XCTAssertEqual(try resolveCommission(using: allowed, route: route)?.estimatedAmount, expectedAmount)
    }

    func testChargesWhenChargedAssetHasNoLocalExistentialDeposit() throws {
        // Native assets keep their ED in runtime constants, which cannot be read synchronously — charging
        // is the documented fallback, matching the behaviour before the ED guard existed.
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 1_000_000)

        XCTAssertEqual(try resolveCommission(using: policy, route: route)?.estimatedAmount, 8428)
    }

    func testSkipsForZeroAmount() throws {
        let policy = CommissionTestFixtures.createPolicy()
        let route = CommissionTestFixtures.createRoute([.hydraSwap], amount: 117)

        let commission = try resolveCommission(using: policy, route: route)

        XCTAssertNil(commission)
    }

    func testGrossUpIsCeilingAndPathScoped() {
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertEqual(
            policy.grossingUpAmountOut(1_000_000_000, for: CommissionTestFixtures.createPath([.hydraSwap])),
            1_008_500_000
        )
        XCTAssertEqual(
            policy.grossingUpAmountOut(1_000_000_000, for: CommissionTestFixtures.createPath([.crossChain])),
            1_000_000_000
        )
    }

    func testBuyGrossUpRoundTripsExactly() {
        let policy = CommissionTestFixtures.createPolicy()
        let path = CommissionTestFixtures.createPath([.hydraSwap])

        let targets: [Balance] = [1, 2, 117, 118, 999, 1_000_000_000, 123_456_789_012_345]

        for target in targets {
            let gross = policy.grossingUpAmountOut(target, for: path)
            let net = policy.netAmount(from: gross, willCharge: true)

            // Commission is 0.85% of what the user receives, so grossing up and then deducting
            // returns exactly the entered amount — no residual plank in either direction.
            XCTAssertEqual(net, target)
        }
    }

    func testNetAmountAppliesRateNotAbsoluteAmount() {
        let policy = CommissionTestFixtures.createPolicy()

        XCTAssertEqual(policy.netAmount(from: 1_000_000, willCharge: true), 991_572)
        XCTAssertEqual(policy.netAmount(from: 1_000_000, willCharge: false), 1_000_000)
    }

    func testArithmeticAtExtremes() {
        let policy = CommissionTestFixtures.createPolicy()
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

        let policy = CommissionTestFixtures.createPolicy()
        let chargingOperationIndex = try XCTUnwrap(policy.chargingOperationIndex(in: path))

        let commission = AssetExchangeCommission(
            chargingOperationIndex: chargingOperationIndex,
            asset: CommissionTestFixtures.asset(expectedChargedAssetId),
            estimatedAmount: 1,
            beneficiary: CommissionTestFixtures.beneficiary,
            rateOfGross: AssetExchangeCommissionConstants.rate.asShareOfGross
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
