import Foundation
import Operation_iOS
import SubstrateSdk

protocol ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(for request: PolkadotVaultWallet, type: ParitySignerType) -> BaseOperation<MetaAccountModel>
}

final class ParitySignerWalletOperationFactory {}

private extension ParitySignerWalletOperationFactory {
    func newLegacyHardwareWalletFromSingle(
        name: String,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let account = try update.ensureSingleAccount()
            let publicKey = try account.getPublicKey()

            switch account.scheme {
            case .substrate:
                return MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: name,
                    substrateAccountId: account.accountId,
                    substrateCryptoType: account.cryptoType.rawValue,
                    substratePublicKey: publicKey,
                    ethereumAddress: nil,
                    ethereumPublicKey: nil,
                    chainAccounts: [],
                    type: .paritySigner
                )
            case .evm:
                return MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: name,
                    substrateAccountId: nil,
                    substrateCryptoType: nil,
                    substratePublicKey: nil,
                    ethereumAddress: account.accountId,
                    ethereumPublicKey: publicKey,
                    chainAccounts: [],
                    type: .paritySigner
                )
            }
        }
    }

    func newConsensusBasedHardwareWallet(
        name: String,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let chainAccounts = try update.addressItems.map { addressItem in
                let publicKey = try addressItem.getPublicKey()

                return ChainAccountModel(
                    chainId: addressItem.genesisHash.toHex(),
                    accountId: addressItem.accountId,
                    publicKey: publicKey,
                    cryptoType: addressItem.cryptoType.rawValue,
                    proxy: nil
                )
            }

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: Set(chainAccounts),
                type: .polkadotVault
            )
        }
    }
}

extension ParitySignerWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(
        for request: PolkadotVaultWallet,
        type: ParitySignerType
    ) -> BaseOperation<MetaAccountModel> {
        switch type {
        case .legacy:
            newLegacyHardwareWalletFromSingle(name: request.name, update: request.update)
        case .vault:
            newConsensusBasedHardwareWallet(name: request.name, update: request.update)
        }
    }
}

extension ParitySignerType {
    var walletType: MetaAccountModelType {
        switch self {
        case .legacy:
            return .paritySigner
        case .vault:
            return .polkadotVault
        }
    }
}
