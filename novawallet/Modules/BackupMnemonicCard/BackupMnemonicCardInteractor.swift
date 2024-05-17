import IrohaCrypto
import SoraFoundation
import SoraKeystore
import RobinHood

final class BackupMnemonicCardInteractor {
    weak var presenter: BackupMnemonicCardInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private let keystore: KeystoreProtocol
    private let operationManager: OperationManagerProtocol

    init(
        metaAccount: MetaAccountModel,
        keystore: KeystoreProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.metaAccount = metaAccount
        self.keystore = keystore
        self.operationManager = operationManager
    }
}

extension BackupMnemonicCardInteractor: BackupMnemonicCardInteractorInputProtocol {
    func fetchMnemonic() {
        let exportOperation: BaseOperation<IRMnemonicProtocol> = ClosureOperation { [weak self] in
            guard let metaAccount = self?.metaAccount else {
                throw ExportMnemonicInteractorError.missingAccount
            }

            let entropyTag = KeystoreTagV2.entropyTagForMetaId(metaAccount.metaId)

            guard let entropy = try self?.keystore.loadIfKeyExists(entropyTag) else {
                throw ExportMnemonicInteractorError.missingEntropy
            }

            return try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let mnemonic = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter?.didReceive(mnemonic: mnemonic)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}
