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
        let title = R.string.localizable.settingsBiometryAuthAlertTitle(
            biometryTypeName,
            preferredLanguages: languages
        )
        let message = R.string.localizable.settingsBiometryAuthAlertMessage(
            biometryTypeName,
            preferredLanguages: languages
        )
        let alertModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [
                .init(
                    title: R.string.localizable.commonOk(preferredLanguages: languages),
                    handler: useAction
                ),
                .init(
                    title: R.string.localizable.settingsBiometryAuthAlertDisableButton(preferredLanguages: languages),
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
        let title = R.string.localizable.settingsApproveWithPinAlertTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.settingsApproveWithPinAlertMessage(preferredLanguages: locale.rLanguages)
        let enableButtonTitle = R.string.localizable.settingsApproveWithPinAlertEnableButtonTitle(
            preferredLanguages: locale.rLanguages)
        let alertModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [
                .init(
                    title: enableButtonTitle,
                    handler: enableAction
                ),
                .init(
                    title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
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
