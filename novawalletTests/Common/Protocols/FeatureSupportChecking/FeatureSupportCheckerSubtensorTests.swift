import XCTest
@testable import novawallet

final class FeatureSupportCheckerSubtensorTests: XCTestCase {
    func testGenericLedgerWalletPassesAvailabilityAndSigningChecks() throws {
        let result = try checkStakingSupport(for: .genericLedger)

        XCTAssertTrue(result.isAvailable)
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .genericLedger))
    }

    func testLegacyLedgerWalletPassesAvailabilityAndSigningChecks() throws {
        let result = try checkStakingSupport(for: .ledger)

        XCTAssertTrue(result.isAvailable)
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .ledger))
    }

    func testProxiedWalletFailsAvailabilityAndSigningChecks() throws {
        let result = try checkStakingSupport(for: .proxied)

        guard case let .noSubtensorStakingSupport(walletType) = result else {
            return XCTFail("Unexpected result: \(result)")
        }

        XCTAssertEqual(walletType, .proxied)
        XCTAssertTrue(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .proxied))
    }

    func testSigningCheckDefersMultisigWalletToDelayedExecutionCheck() {
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .multisig))
    }
}

private extension FeatureSupportCheckerSubtensorTests {
    func checkStakingSupport(for walletType: MetaAccountModelType) throws -> OperationCheckCommonResult {
        let checker = FeatureSupportChecker(
            chainRegistry: MockChainRegistryProtocol(),
            userStorageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let wallet = AccountGenerator.generateMetaAccount(type: walletType)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

        let completion = expectation(description: "Subtensor staking support check")
        var checkResult: OperationCheckCommonResult?

        checker.checkSubtensorStakingSupport(for: wallet, chain: chain) { result in
            checkResult = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: Constants.defaultExpectationDuration)

        return try XCTUnwrap(checkResult)
    }
}
