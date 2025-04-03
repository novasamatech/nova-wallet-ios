import Foundation
import Keystore_iOS
import NovaCrypto
import Operation_iOS

protocol MnemonicFetchingInput: AnyObject {
    var mnemonicOutput: MnemonicFetchingOutput? { get }
    var metaAccount: MetaAccountModel { get }
    var chain: ChainModel? { get set }
    var keystore: KeystoreProtocol { get }
    var operationQueue: OperationQueue { get }

    func fetchMnemonic()
}

extension MnemonicFetchingInput {
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
                self?.mnemonicOutput?.didReceive(mnemonic: mnemonic)
            case let .failure(error):
                self?.mnemonicOutput?.didReceive(error: error)
            }
        }
    }
}

protocol MnemonicFetchingOutput: AnyObject {
    func didReceive(mnemonic: IRMnemonicProtocol)
    func didReceive(error: Error)
}
