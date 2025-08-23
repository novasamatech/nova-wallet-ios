import Foundation

struct PolkadotVaultWalletUpdate {
    struct AddressItem {
        let accountId: AccountId
        let genesisHash: Data
        let scheme: HardwareWalletAddressScheme

        /*
         * Old versions of PV doesn't provide public key
         * making the assumption that it is same as account id for sr25519 crypto.
         * However that is not true for evm.
         */
        let publicKey: Data?

        var cryptoType: MultiassetCryptoType {
            switch scheme {
            case .substrate:
                .sr25519
            case .evm:
                .ethereumEcdsa
            }
        }
    }

    let addressItems: [AddressItem]
}

enum PolkadotVaultWalletUpdateError: Error {
    case expectedSingleAccount
    case publicKeyExpected
    case multipleAccountsPerChain
}

extension PolkadotVaultWalletUpdate.AddressItem {
    func getPublicKey() throws -> Data {
        switch cryptoType {
        case .sr25519, .ed25519:
            return accountId
        case .substrateEcdsa, .ethereumEcdsa:
            guard let publicKey = publicKey else {
                throw PolkadotVaultWalletUpdateError.publicKeyExpected
            }

            return publicKey
        }
    }
}

extension PolkadotVaultWalletUpdate {
    func ensureSingleAccount() throws -> PolkadotVaultWalletUpdate.AddressItem {
        guard addressItems.count == 1, let item = addressItems.first else {
            throw PolkadotVaultWalletUpdateError.expectedSingleAccount
        }

        return item
    }

    func ensureSingleAccountPerChain() throws {
        let genesisHashes = addressItems
            .map(\.genesisHash)
            .distinct()

        if genesisHashes.count != addressItems.count {
            throw PolkadotVaultWalletUpdateError.multipleAccountsPerChain
        }
    }

    func ensurePublicKeysValid() throws {
        try addressItems.forEach { addressItem in
            _ = try addressItem.getPublicKey()
        }
    }

    func toChainAccountModels() throws -> [ChainAccountModel] {
        try addressItems.map { addressItem in
            let publicKey = try addressItem.getPublicKey()

            return ChainAccountModel(
                chainId: addressItem.genesisHash.toHex(),
                accountId: addressItem.accountId,
                publicKey: publicKey,
                cryptoType: addressItem.cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )
        }
    }
}
