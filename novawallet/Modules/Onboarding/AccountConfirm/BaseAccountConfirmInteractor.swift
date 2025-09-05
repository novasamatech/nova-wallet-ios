import UIKit
import Keystore_iOS
import NovaCrypto
import Operation_iOS

class BaseAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let request: MetaAccountCreationRequest
    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]
    let accountOperationFactory: MetaAccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue

    init(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.request = request
        self.mnemonic = mnemonic
        shuffledWords = mnemonic.allWords().shuffled()
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
    }

    internal func createAccountUsingOperation(_: BaseOperation<MetaAccountModel>) {
        fatalError("This function should be overriden")
    }
}

extension BaseAccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
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

        let operation = accountOperationFactory.newSecretsMetaAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }

    func skipConfirmation() {
        let operation = accountOperationFactory.newSecretsMetaAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }
}
