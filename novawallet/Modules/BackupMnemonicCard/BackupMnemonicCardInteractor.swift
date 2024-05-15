import UIKit

final class BackupMnemonicCardInteractor {
    weak var presenter: BackupMnemonicCardInteractorOutputProtocol?
}

extension BackupMnemonicCardInteractor: BackupMnemonicCardInteractorInputProtocol {}
