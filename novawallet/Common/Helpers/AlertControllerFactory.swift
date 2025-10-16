import Foundation
import UIKit
import Foundation_iOS

extension UIAlertController {
    static func phishingWarningAlert(
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        locale: Locale,
        displayName paramValue: String
    ) -> UIAlertController {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.walletSendPhishingWarningTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendPhishingWarningText(paramValue)

        let cancelTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        let proceedTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue()

        let proceedAction = UIAlertAction(title: proceedTitle, style: .default) { _ in onConfirm() }
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in onCancel() }

        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(proceedAction)
        alertController.addAction(cancelAction)

        return alertController
    }
}
