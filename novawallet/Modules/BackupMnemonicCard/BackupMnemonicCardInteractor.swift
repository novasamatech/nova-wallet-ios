import IrohaCrypto
import SoraFoundation
import SoraKeystore
import RobinHood

final class BackupMnemonicCardInteractor {
    weak var presenter: BackupMnemonicCardInteractorOutputProtocol?

    private let metaAccount: MetaAccountModel
    private var chain: ChainModel?
    private let keystore: KeystoreProtocol
    private let operationQueue: OperationQueue

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel?,
        keystore: KeystoreProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaAccount = metaAccount
        self.chain = chain
        self.keystore = keystore
        self.operationQueue = operationQueue
    }
}

extension BackupMnemonicCardInteractor: BackupMnemonicCardInteractorInputProtocol {
    func fetchMnemonic() {
        let exportOperation: BaseOperation<IRMnemonicProtocol> = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            var accountId: AccountId? {
                if let chain {
                    metaAccount.fetchChainAccountId(for: chain.accountRequest())
                } else {
                    .none
                }
            }

            let entropyTag = KeystoreTagV2.entropyTagForMetaId(
                metaAccount.metaId,
                accountId: accountId
            )

            guard let entropy = try keystore.loadIfKeyExists(entropyTag) else {
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
