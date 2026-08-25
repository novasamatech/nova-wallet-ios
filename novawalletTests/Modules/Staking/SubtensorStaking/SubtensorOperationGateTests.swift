@testable import novawallet
import XCTest

final class SubtensorOperationGateTests: XCTestCase {
    func testSecretsWalletIsAllowed() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .secrets), .allowed)
    }

    func testParitySignerWalletIsAllowed() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .paritySigner), .allowed)
    }

    func testPolkadotVaultWalletIsAllowed() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .polkadotVault), .allowed)
    }

    func testLegacyLedgerWalletIsGatedOff() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .ledger), .signerNotSupported(.ledger))
    }

    func testGenericLedgerWalletIsGatedOff() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .genericLedger), .signerNotSupported(.ledger))
    }

    func testProxiedWalletGetsProxyMessaging() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .proxied), .signerNotSupported(.proxy))
    }

    func testMultisigWalletGetsMultisigMessaging() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .multisig), .signerNotSupported(.multisig))
    }

    func testWatchOnlyWalletHasNoSigning() {
        XCTAssertEqual(SubtensorOperationGate.verdict(for: .watchOnly), .noSigning)
    }
}
