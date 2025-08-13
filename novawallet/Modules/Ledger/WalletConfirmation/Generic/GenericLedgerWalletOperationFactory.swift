import Foundation
import Keystore_iOS
import Operation_iOS

protocol GenericLedgerWalletOperationFactoryProtocol {
    func createSaveOperation(
        for model: PolkadotLedgerWalletModel,
        name: String,
        keystore: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) -> BaseOperation<Void>

    func createUpdateEvmWrapper(
        for model: LedgerEvmAccountResponse,
        wallet: MetaAccountModel,
        keystore: KeystoreProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>
    ) -> CompoundOperationWrapper<Void>
}

final class GenericLedgerWalletOperationFactory: GenericLedgerWalletOperationFactoryProtocol {
    func createSaveOperation(
        for model: PolkadotLedgerWalletModel,
        name: String,
        keystore: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { completion in
            let wallet = MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: model.substrate.accountId,
                substrateCryptoType: model.substrate.cryptoType.rawValue,
                substratePublicKey: model.substrate.publicKey,
                ethereumAddress: model.evm?.address,
                ethereumPublicKey: model.evm?.publicKey,
                chainAccounts: [],
                type: .genericLedger,
                multisig: nil
            )

            let substrateTag = KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)

            try keystore.saveKey(model.substrate.derivationPath, with: substrateTag)

            if let evm = model.evm {
                let evmTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)
                try keystore.saveKey(evm.derivationPath, with: evmTag)
            }

            settings.save(
                value: wallet,
                runningCompletionIn: nil
            ) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    func createUpdateEvmWrapper(
        for model: LedgerEvmAccountResponse,
        wallet: MetaAccountModel,
        keystore: KeystoreProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>
    ) -> CompoundOperationWrapper<Void> {
        let updateWalletOperation = ClosureOperation<MetaAccountModel> {
            let accountId = try model.account.address.toAccountId(using: .ethereum)

            let newWallet = wallet
                .replacingEthereumAddress(accountId)
                .replacingEthereumPublicKey(model.account.publicKey)

            let evmTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)
            try keystore.saveKey(model.derivationPath, with: evmTag)

            return newWallet
        }

        let saveOperation = repository.saveOperation({
            let updatedWallet = try updateWalletOperation.extractNoCancellableResultData()

            return [updatedWallet]
        }, {
            []
        })

        saveOperation.addDependency(updateWalletOperation)

        return CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [updateWalletOperation]
        )
    }
}
