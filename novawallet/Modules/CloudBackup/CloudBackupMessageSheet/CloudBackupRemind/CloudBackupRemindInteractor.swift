import UIKit
import Keystore_iOS

final class CloudBackupRemindInteractor {
    let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }
}

extension CloudBackupRemindInteractor: CloudBackupRemindInteractorInputProtocol {
    func saveNoConfirmation(for completion: @escaping () -> Void) {
        settings.cloudBackupAutoSyncConfirm = true
        completion()
    }
}
