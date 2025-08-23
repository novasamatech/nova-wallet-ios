import Foundation
import Operation_iOS
import SubstrateSdk

protocol ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(for request: PolkadotVaultWallet, type: ParitySignerType) -> BaseOperation<MetaAccountModel>

    func updateHardwareWallet(
        for wallet: MetaAccountModel,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel>
}

enum ParitySignerWalletOperationFactoryError: Error {
    case unsupportedWalletUpdate
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
                    type: .paritySigner,
                    multisig: nil
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
                    type: .paritySigner,
                    multisig: nil
                )
            }
        }
    }

    func newConsensusBasedHardwareWallet(
        name: String,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let chainAccounts = try update.toChainAccountModels()

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: Set(chainAccounts),
                type: .polkadotVault,
                multisig: nil
            )
        }
    }

    func updateConsensusBasedWallet(
        _ wallet: MetaAccountModel,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let newChainAccounts = try update.toChainAccountModels()
            let newChainIds = Set(newChainAccounts.map(\.chainId))
            let existingChainAccounts = wallet.chainAccounts.filter { !newChainIds.contains($0.chainId) }

            let updatedChainAccounts = existingChainAccounts + newChainAccounts

            return MetaAccountModel(
                metaId: wallet.metaId,
                name: wallet.name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: Set(updatedChainAccounts),
                type: .polkadotVault,
                multisig: nil
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

    func updateHardwareWallet(
        for wallet: MetaAccountModel,
        update: PolkadotVaultWalletUpdate
    ) -> BaseOperation<MetaAccountModel> {
        guard case .polkadotVault = wallet.type else {
            return .createWithError(ParitySignerWalletOperationFactoryError.unsupportedWalletUpdate)
        }

        return updateConsensusBasedWallet(wallet, update: update)
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
