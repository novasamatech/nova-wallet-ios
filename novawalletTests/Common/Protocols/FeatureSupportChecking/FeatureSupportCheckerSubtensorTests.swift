import XCTest
@testable import novawallet

final class FeatureSupportCheckerSubtensorTests: XCTestCase {
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)

    func testLedgerAccountsPassAvailabilityGate() {
        for walletType in [MetaAccountModelType.ledger, .genericLedger] {
            let result = checkAvailability(for: walletType)

            XCTAssertTrue(result.isAvailable, "\(walletType) must see Bittensor staking")
        }
    }

    func testLedgerAccountsPassSigningGate() {
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .ledger))
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .genericLedger))
    }

    func testProxiedAccountsStayExcludedOnBothGates() {
        let result = checkAvailability(for: .proxied)

        guard case let .noSubtensorStakingSupport(walletType) = result else {
            return XCTFail("Unexpected availability result: \(result)")
        }

        XCTAssertEqual(walletType, .proxied)
        XCTAssertTrue(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .proxied))
    }

    func testMultisigIsDeferredToDelayedExecutionCheck() {
        // Multisig is decided by the delayed-execution check, so the synchronous signing gate must not refuse it.
        XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: .multisig))
    }

    func testLocalWalletsPassBothGates() {
        for walletType in [MetaAccountModelType.secrets, .paritySigner, .polkadotVault] {
            XCTAssertTrue(checkAvailability(for: walletType).isAvailable, "\(walletType) must see Bittensor staking")
            XCTAssertFalse(FeatureSupportChecker.refusesSubtensorStakingSigning(for: walletType))
        }
    }

    // MARK: - Private

    private func checkAvailability(for walletType: MetaAccountModelType) -> OperationCheckCommonResult {
        let checker = FeatureSupportChecker(
            chainRegistry: MockChainRegistryProtocol(),
            userStorageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let wallet = AccountGenerator.generateMetaAccount(type: walletType)
        let expectation = expectation(description: "support check for \(walletType)")
        var received: OperationCheckCommonResult?

        checker.checkSubtensorStakingSupport(for: wallet, chain: chain) { result in
            received = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        return received ?? .noSigning
    }
}
