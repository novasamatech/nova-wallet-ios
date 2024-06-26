import Foundation
import SoraKeystore
import Operation_iOS

protocol GenericLedgerWalletOperationFactoryProtocol {
    func createSaveOperation(
        for model: SubstrateLedgerWalletModel,
        name: String,
        keystore: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) -> BaseOperation<Void>
}

final class GenericLedgerWalletOperationFactory: GenericLedgerWalletOperationFactoryProtocol {
    func createSaveOperation(
        for model: SubstrateLedgerWalletModel,
        name: String,
        keystore: KeystoreProtocol,
        settings: SelectedWalletSettings
    ) -> BaseOperation<Void> {
        AsyncClosureOperation { completion in
            let wallet = MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: model.accountId,
                substrateCryptoType: model.cryptoType.rawValue,
                substratePublicKey: model.publicKey,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .genericLedger
            )

            let tag = KeystoreTagV2.substrateDerivationTagForMetaId(
                wallet.metaId,
                accountId: model.accountId
            )

            try keystore.saveKey(model.derivationPath, with: tag)

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
