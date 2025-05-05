import NovaCrypto
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

final class BackupMnemonicCardInteractor: BackupMnemonicCardInteractorInputProtocol {
    weak var presenter: BackupMnemonicCardInteractorOutputProtocol?

    var mnemonicOutput: MnemonicFetchingOutput? { presenter }
    let metaAccount: MetaAccountModel
    var chain: ChainModel?
    let keystore: KeystoreProtocol
    let operationQueue: OperationQueue

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
