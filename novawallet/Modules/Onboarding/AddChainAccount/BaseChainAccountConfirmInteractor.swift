import UIKit
import Keystore_iOS
import NovaCrypto
import Operation_iOS

class BaseChainAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let request: ChainAccountImportMnemonicRequest
    let metaAccountModel: MetaAccountModel
    let chainModelId: ChainModel.Id
    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]
    let metaAccountOperationFactory: MetaAccountOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        mnemonic: IRMnemonicProtocol,
        metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.metaAccountModel = metaAccountModel
        self.chainModelId = chainModelId
        self.mnemonic = mnemonic
        shuffledWords = mnemonic.allWords().shuffled()
        self.metaAccountOperationFactory = metaAccountOperationFactory
        self.operationQueue = operationQueue
    }

    internal func createAccountUsingOperation(_: BaseOperation<MetaAccountModel>) {
        fatalError("This function should be overriden")
    }
}

extension BaseChainAccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        presenter.didReceive(words: shuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == mnemonic.allWords() else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }

        let operation = metaAccountOperationFactory.replaceChainAccountOperation(
            for: metaAccountModel,
            request: request,
            chainId: chainModelId
        )

        createAccountUsingOperation(operation)
    }

    func skipConfirmation() {
        let operation = metaAccountOperationFactory.replaceChainAccountOperation(
            for: metaAccountModel,
            request: request,
            chainId: chainModelId
        )

        createAccountUsingOperation(operation)
    }
}
