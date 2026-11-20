@testable import novawallet
import SubstrateSdk
import XCTest

final class DAppTxPayloadSignerPolicyTests: XCTestCase {
    private let allTypes: [MetaAccountModelType] = [
        .secrets, .watchOnly, .paritySigner, .polkadotVault, .ledger, .genericLedger, .proxied, .multisig
    ]

    func testEverySignerTypeSignsLegacyExtrinsic() {
        for signerType in allTypes {
            XCTAssertNoThrow(try DAppTxPayloadSignerPolicy.ensureCanSign(.V4, signerType: signerType), "\(signerType)")
        }
    }

    func testGeneralTransactionIsSignedOnlyWithKeysOfWallet() {
        let version = Extrinsic.Version.V5(extensionVersion: 0)

        // a watch-only wallet passes to keep its own "no keys" message, a delegated one is judged by its delegate
        for signerType in [MetaAccountModelType.secrets, .watchOnly, .proxied, .multisig] {
            XCTAssertNoThrow(
                try DAppTxPayloadSignerPolicy.ensureCanSign(version, signerType: signerType),
                "\(signerType)"
            )
        }

        for signerType in [MetaAccountModelType.paritySigner, .polkadotVault, .ledger, .genericLedger] {
            XCTAssertThrowsError(
                try DAppTxPayloadSignerPolicy.ensureCanSign(version, signerType: signerType),
                "\(signerType)"
            ) { error in
                XCTAssertEqual((error as? DAppCreateTransactionError)?.name, "SignerUnavailable")
            }
        }
    }

    func testWalletOverridesNonceOnlyWhenAnotherAccountSigns() throws {
        let chain = try ExtrinsicGoldenRuntime.makeChain()
        let nonceId = Extrinsic.TransactionExtensionId.nonce

        for signerType in allTypes {
            let account = makeAccount(for: chain, type: signerType)

            let current = DAppTxPayloadSignerPolicy.walletOverriddenIds(for: .current(account), hasMetadataHash: false)
            let delegate = DAppTxPayloadSignerPolicy.walletOverriddenIds(
                for: makeDelegate(of: account, chain: chain, signerType: .secrets),
                hasMetadataHash: false
            )

            XCTAssertEqual(current, [], "\(signerType)")
            XCTAssertEqual(delegate, [nonceId], "\(signerType)")
        }
    }

    func testWalletOverridesMetadataHashOnlyForLedgerThatHasOne() throws {
        let chain = try ExtrinsicGoldenRuntime.makeChain()
        let metadataHashId = Extrinsic.TransactionExtensionId.checkMetadataHash
        let nonceId = Extrinsic.TransactionExtensionId.nonce

        for signerType in allTypes {
            let sender = ExtrinsicSenderResolution.current(makeAccount(for: chain, type: signerType))
            let isLedger = signerType == .ledger || signerType == .genericLedger

            XCTAssertEqual(
                DAppTxPayloadSignerPolicy.walletOverriddenIds(for: sender, hasMetadataHash: true),
                isLedger ? [metadataHashId] : [],
                "\(signerType)"
            )

            XCTAssertEqual(
                DAppTxPayloadSignerPolicy.walletOverriddenIds(for: sender, hasMetadataHash: false),
                [],
                "\(signerType)"
            )
        }

        // a proxied wallet whose delegate is a Ledger: both rules apply to the delegate
        let delegated = makeDelegate(
            of: makeAccount(for: chain, type: .proxied),
            chain: chain,
            signerType: .genericLedger
        )

        XCTAssertEqual(
            DAppTxPayloadSignerPolicy.walletOverriddenIds(for: delegated, hasMetadataHash: true),
            [nonceId, metadataHashId]
        )
    }
}

private extension DAppTxPayloadSignerPolicyTests {
    func makeAccount(for chain: ChainModel, type: MetaAccountModelType) -> ChainAccountResponse {
        ChainAccountResponse(
            metaId: "policy-wallet",
            chainId: chain.chainId,
            accountId: ExtrinsicGolden.senderId,
            publicKey: ExtrinsicGolden.senderId,
            name: "Policy",
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )
    }

    func makeDelegate(
        of delegatedAccount: ChainAccountResponse,
        chain: ChainModel,
        signerType: MetaAccountModelType
    ) -> ExtrinsicSenderResolution {
        let delegateAccount = makeAccount(for: chain, type: signerType)

        return .delegate(
            ExtrinsicSenderResolution.ResolvedDelegate(
                delegateAccount: MetaChainAccountResponse(
                    metaId: delegateAccount.metaId,
                    substrateAccountId: delegateAccount.accountId,
                    ethereumAccountId: nil,
                    walletIdenticonData: nil,
                    delegationId: nil,
                    chainAccount: delegateAccount
                ),
                delegatedAccount: delegatedAccount,
                paths: [:],
                allWallets: [],
                chain: chain,
                failures: []
            )
        )
    }
}
