import Foundation
import SoraFoundation

final class CloudBackupCreatePasswordPresenter: BaseCloudBackupCreatePresenter {
    override func createValidation() -> CloudBackup.PasswordValidationType {
        .newPassword(password: password)
    }

    override func actionContinue() {
        guard let password else { return }

        wireframe.proceed(
            from: view,
            password: password,
            locale: selectedLocale
        )
    }

    override func actionOnAppear() {
        wireframe.showPasswordHint(from: view)
    }
}
