import UIKit

protocol OperationAuthPresentable: AlertPresentable {
    func askBiometryUsage(
        from view: ControllerBackedProtocol,
        biometrySettings: BiometrySettings,
        locale: Locale,
        useAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    )

    func presentConfirmPinHint(
        from view: ControllerBackedProtocol,
        locale: Locale,
        enableAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    )
}

extension OperationAuthPresentable {
    func askBiometryUsage(
        from view: ControllerBackedProtocol,
        biometrySettings: BiometrySettings,
        locale: Locale,
        useAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) {
        let biometryTypeName = biometrySettings.name
        let languages = locale.rLanguages
        let title = R.string(preferredLanguages: languages
        ).localizable.settingsBiometryAuthAlertTitle(biometryTypeName)
        let message = R.string(preferredLanguages: languages
        ).localizable.settingsBiometryAuthAlertMessage(biometryTypeName)
        let alertModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [
                .init(
                    title: R.string(preferredLanguages: languages).localizable.commonOk(),
                    handler: useAction
                ),
                .init(
                    title: R.string(preferredLanguages: languages).localizable.settingsBiometryAuthAlertDisableButton(),
                    style: .cancel,
                    handler: skipAction
                )
            ], closeAction: nil
        )

        present(viewModel: alertModel, style: .alert, from: view)
    }

    func presentConfirmPinHint(
        from view: ControllerBackedProtocol,
        locale: Locale,
        enableAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.settingsApproveWithPinAlertTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.settingsApproveWithPinAlertMessage()
        let enableButtonTitle = R.string(preferredLanguages: locale.rLanguages).localizable.settingsApproveWithPinAlertEnableButtonTitle()
        let alertModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [
                .init(
                    title: enableButtonTitle,
                    handler: enableAction
                ),
                .init(
                    title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel(),
                    style: .cancel,
                    handler: cancelAction
                )
            ],
            closeAction: nil
        )

        present(
            viewModel: alertModel,
            style: .alert,
            from: view
        )
    }
}
