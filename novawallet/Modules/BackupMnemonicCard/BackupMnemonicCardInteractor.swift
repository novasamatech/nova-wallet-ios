import IrohaCrypto
import SoraFoundation
import SoraKeystore
import RobinHood

final class BackupMnemonicCardInteractor {
    weak var presenter: BackupMnemonicCardInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private let keystore: KeystoreProtocol
    private let operationQueue: OperationQueue

    init(
        metaAccount: MetaAccountModel,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaAccount = metaAccount
        self.keystore = keystore
        self.operationQueue = operationQueue
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

        execute(
            operation: exportOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(mnemonic):
                self?.presenter?.didReceive(mnemonic: mnemonic)
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }
    }
}
