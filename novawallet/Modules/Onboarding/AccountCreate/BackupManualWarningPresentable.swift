import Foundation

protocol BackupManualWarningPresentable {
    func presentBackupManualWarning(
        from view: ControllerBackedProtocol?,
        locale: Locale,
        onProceed: @escaping () -> Void,
        onCancel: @escaping () -> Void
    )
}

extension BackupManualWarningPresentable where Self: AlertPresentable {
    private func createCancelAction(for locale: Locale, onCancel: @escaping () -> Void) -> AlertPresentableAction {
        let cancelTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        return AlertPresentableAction(title: cancelTitle, style: .destructive, handler: onCancel)
    }

    private func createProceedAction(for locale: Locale, onProceed: @escaping () -> Void) -> AlertPresentableAction {
        let proceedTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonUnderstand()
        return AlertPresentableAction(title: proceedTitle, style: .normal, handler: onProceed)
    }

    private func createWarningViewModel(
        for locale: Locale,
        onProceed: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> AlertPresentableViewModel {
        let alertTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonNoScreenshotTitle_v2_2_0()

        let alertMessage = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNoScreenshotMessage_v2_2_0()

        let cancelAction = createCancelAction(for: locale, onCancel: onCancel)
        let proceedAction = createProceedAction(for: locale, onProceed: onProceed)
        let actions = [cancelAction, proceedAction]

        return AlertPresentableViewModel(title: alertTitle, message: alertMessage, actions: actions, closeAction: nil)
    }

    func presentBackupManualWarning(
        from view: ControllerBackedProtocol?,
        locale: Locale,
        onProceed: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let viewModel = createWarningViewModel(for: locale, onProceed: onProceed, onCancel: onCancel)
        present(viewModel: viewModel, style: .alert, from: view)
    }
}
