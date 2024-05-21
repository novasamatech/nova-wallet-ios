import UIKit

final class ManualBackupKeyListInteractor {
    weak var presenter: ManualBackupKeyListInteractorOutputProtocol?
}

extension ManualBackupKeyListInteractor: ManualBackupKeyListInteractorInputProtocol {}