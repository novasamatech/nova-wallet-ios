import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

enum ExportMnemonicInteractorError: Error {
    case missingAccount
    case missingEntropy
}

final class ExportMnemonicInteractor {
    weak var presenter: ExportMnemonicInteractorOutputProtocol!

    let metaAccount: MetaAccountModel
    let chain: ChainModel
    let keystore: KeystoreProtocol
    let operationManager: OperationManagerProtocol

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel,
        keystore: KeystoreProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.metaAccount = metaAccount
        self.chain = chain
        self.keystore = keystore
        self.operationManager = operationManager
    }
}

extension ExportMnemonicInteractor: ExportMnemonicInteractorInputProtocol {
    func fetchExportData() {
        let exportOperation: BaseOperation<ExportMnemonicData> = ClosureOperation { [weak self] in
            guard
                let metaAccount = self?.metaAccount,
                let chain = self?.chain
            else {
                throw ExportMnemonicInteractorError.missingAccount
            }

            let accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())
            let entropyTag = KeystoreTagV2.entropyTagForMetaId(metaAccount.metaId, accountId: accountId)

            guard let entropy = try self?.keystore.loadIfKeyExists(entropyTag) else {
                throw ExportMnemonicInteractorError.missingEntropy
            }

            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)

            let derivationTag = chain.isEthereumBased ?
                KeystoreTagV2.ethereumDerivationTagForMetaId(metaAccount.metaId, accountId: accountId) :
                KeystoreTagV2.substrateDerivationTagForMetaId(metaAccount.metaId, accountId: accountId)

            let derivationPath: String?

            if let derivationPathData = try self?.keystore.loadIfKeyExists(derivationTag) {
                derivationPath = String(data: derivationPathData, encoding: .utf8)
            } else {
                derivationPath = nil
            }

            return ExportMnemonicData(
                metaAccount: metaAccount,
                mnemonic: mnemonic,
                derivationPath: derivationPath,
                chain: chain
            )
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didReceive(exportData: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}
