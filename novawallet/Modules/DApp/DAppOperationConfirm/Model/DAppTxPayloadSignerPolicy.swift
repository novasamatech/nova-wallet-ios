import Foundation
import SubstrateSdk

/**
 *  What the account that actually signs a createTransaction request is allowed to sign
 *  and which of the dApp's extensions it has to replace.
 */
enum DAppTxPayloadSignerPolicy {
    static func ensureCanSign(
        _ extrinsicVersion: Extrinsic.Version,
        signerType: MetaAccountModelType
    ) throws {
        switch (extrinsicVersion, signerType) {
        case (.V4, _),
             (.V5, .secrets),
             (.V5, .watchOnly),
             (.V5, .proxied),
             (.V5, .multisig):
            return
        case (.V5, .paritySigner),
             (.V5, .polkadotVault),
             (.V5, .ledger),
             (.V5, .genericLedger):
            // such a signer displays and signs the whole payload while a v5 signature is made over its hash
            throw DAppCreateTransactionError.signerUnavailable(
                details: "the wallet's signer supports only legacy v4 transactions"
            )
        }
    }

    /**
     *  The extensions that take the wallet's value even when the dApp supplied one.
     */
    static func walletOverriddenIds(
        for sender: ExtrinsicSenderResolution,
        hasMetadataHash: Bool
    ) -> Set<String> {
        var identifiers: Set<String> = []

        // the nonce in the payload belongs to the proxied or multisig account, not to the one that signs
        if case .delegate = sender {
            identifiers.insert(Extrinsic.TransactionExtensionId.nonce)
        }

        switch sender.account.type {
        case .ledger, .genericLedger:
            // the device signs only with the metadata proof that the enabled hash commits to
            if hasMetadataHash {
                identifiers.insert(Extrinsic.TransactionExtensionId.checkMetadataHash)
            }
        case .secrets, .watchOnly, .paritySigner, .polkadotVault, .proxied, .multisig:
            break
        }

        return identifiers
    }
}
