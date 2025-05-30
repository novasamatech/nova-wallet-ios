import Foundation
import SubstrateSdk

struct PolkadotLedgerWalletModel {
    struct Substrate {
        let accountId: AccountId
        let publicKey: Data
        let cryptoType: MultiassetCryptoType
        let derivationPath: Data

        init(
            accountId: AccountId,
            publicKey: Data,
            cryptoType: MultiassetCryptoType,
            derivationPath: Data
        ) {
            self.accountId = accountId
            self.publicKey = publicKey
            self.cryptoType = cryptoType
            self.derivationPath = derivationPath
        }

        init(substrateResponse: LedgerSubstrateAccountResponse) throws {
            accountId = try substrateResponse.account.address.toAccountId()
            publicKey = substrateResponse.account.publicKey
            cryptoType = LedgerConstants.defaultSubstrateCryptoScheme.walletCryptoType
            derivationPath = substrateResponse.derivationPath
        }
    }

    struct EVM {
        let publicKey: Data
        let address: AccountId
        let derivationPath: Data

        init(
            address: AccountId,
            publicKey: Data,
            derivationPath: Data
        ) {
            self.address = address
            self.publicKey = publicKey
            self.derivationPath = derivationPath
        }

        init(evmResponse: LedgerEvmAccountResponse) throws {
            address = try evmResponse.account.publicKey.ethereumAddressFromPublicKey()
            publicKey = evmResponse.account.publicKey
            derivationPath = evmResponse.derivationPath
        }
    }

    let substrate: Substrate
    let evm: EVM?
}
