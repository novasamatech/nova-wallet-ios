import Foundation
@testable import novawallet
import Keystore_iOS

enum KeystoreValidationHelper {
    private static func clearKeystore(
        by metaId: MetaAccountModel.Id,
        accountId: AccountId?,
        keystore: KeystoreProtocol
    ) throws {
        try keystore.deleteKeyIfExists(
            for: KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        )

        try keystore.deleteKeyIfExists(
            for: KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)
        )

        try keystore.deleteKeyIfExists(
            for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId)
        )

        try keystore.deleteKeyIfExists(for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId))
        try keystore.deleteKeyIfExists(for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId))

        try keystore.deleteKeyIfExists(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId))
        try keystore.deleteKeyIfExists(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId))
    }

    static func clearKeystore(for wallet: MetaAccountModel, keystore: KeystoreProtocol) throws {
        try clearKeystore(by: wallet.metaId, accountId: nil, keystore: keystore)

        for chainAccount in wallet.chainAccounts {
            try clearKeystore(by: wallet.metaId, accountId: chainAccount.accountId, keystore: keystore)
        }
    }

    static func validateChainAccountsHaveDerivationPaths(
        for wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> Bool {
        try wallet.chainAccounts.allSatisfy { chainAccount in
            let tag = KeystoreTagV2.derivationTagForMetaId(
                wallet.metaId,
                accountId: chainAccount.accountId,
                isEthereumBased: chainAccount.isEthereumBased
            )

            let derivationPath = try keystore.loadIfKeyExists(tag)

            return derivationPath != nil
        }
    }

    static func validateMainSubstrateDerivationPath(
        for wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> Bool {
        let substrateTag = KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
        let substrateDerPath = try keystore.loadIfKeyExists(substrateTag)

        return substrateDerPath != nil
    }

    static func validateMainEthereumDerivationPath(
        for wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> Bool {
        let ethTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)
        let ethDerPath = try keystore.loadIfKeyExists(ethTag)

        return ethDerPath != nil
    }

    static func validateMainAccountsHaveDerivationPaths(
        for wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> Bool {
        try validateMainSubstrateDerivationPath(for: wallet, keystore: keystore) &&
            validateMainEthereumDerivationPath(for: wallet, keystore: keystore)
    }

    static func validateMnemonicSecrets(
        for wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> Bool {
        if try !keystore.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)) {
            return false
        }

        if try !keystore.checkKey(for: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)) {
            return false
        }

        if try !keystore.checkKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)) {
            return false
        }

        if try !keystore.checkKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)) {
            return false
        }

        for chainAccount in wallet.chainAccounts {
            if try !keystore.checkKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)) {
                return false
            }

            if chainAccount.isEthereumBased {
                if try !keystore.checkKey(
                    for: KeystoreTagV2.ethereumSeedTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
                ) {
                    return false
                }

                if try !keystore.checkKey(
                    for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
                ) {
                    return false
                }
            } else {
                if try !keystore.checkKey(
                    for: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
                ) {
                    return false
                }

                if try !keystore.checkKey(
                    for: KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
                ) {
                    return false
                }
            }
        }

        return true
    }
}
