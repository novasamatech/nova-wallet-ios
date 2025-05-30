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
                type: .genericLedger
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
}
