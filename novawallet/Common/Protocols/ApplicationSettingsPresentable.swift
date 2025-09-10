import UIKit

protocol ApplicationSettingsPresentable {
    func askOpenApplicationSettings(
        with message: String,
        title: String?,
        from view: ControllerBackedProtocol?,
        locale: Locale?
    )
}

extension ApplicationSettingsPresentable {
    func askOpenApplicationSettings(
        with message: String,
        title: String?,
        from view: ControllerBackedProtocol?,
        locale: Locale?
    ) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let closeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonNotNow()
        let closeAction = UIAlertAction(title: closeTitle, style: .cancel, handler: nil)

        let settingsTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonOpenSettings()
        let settingsAction = UIAlertAction(title: settingsTitle, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        alert.addAction(closeAction)
        alert.addAction(settingsAction)

        controller.present(alert, animated: true, completion: nil)
    }
}
