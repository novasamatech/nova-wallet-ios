import UIKit

final class CloudBackupSettingsInteractor {
    weak var presenter: CloudBackupSettingsInteractorOutputProtocol?
}

extension CloudBackupSettingsInteractor: CloudBackupSettingsInteractorInputProtocol {}
