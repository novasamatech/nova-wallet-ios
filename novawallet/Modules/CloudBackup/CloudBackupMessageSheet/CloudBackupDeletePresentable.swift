import Foundation

enum CloudBackupDeleteReason {
    case forgotPassword
    case brokenOrEmpty
    case regular
}

protocol CloudBackupDeletePresentable: AlertPresentable {
    func showCloudBackupDelete(
        from view: ControllerBackedProtocol?,
        reason: CloudBackupDeleteReason,
        locale: Locale,
        deleteClosure: @escaping MessageSheetCallback
    )
}

extension CloudBackupDeletePresentable {
    private func createMessageSheet(
        for reason: CloudBackupDeleteReason,
        confirmationClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        switch reason {
        case .forgotPassword:
            return CloudBackupMessageSheetViewFactory.createNoOrForgotPassword(
                deleteClosure: confirmationClosure,
                cancelClosure: nil
            )
        case .brokenOrEmpty:
            return CloudBackupMessageSheetViewFactory.createEmptyOrBrokenBackup(
                deleteClosure: confirmationClosure,
                cancelClosure: nil
            )
        case .regular:
            return CloudBackupMessageSheetViewFactory.createDeleteBackupSheet(
                deleteClosure: confirmationClosure,
                cancelClosure: nil
            )
        }
    }

    func showCloudBackupDelete(
        from view: ControllerBackedProtocol?,
        reason: CloudBackupDeleteReason,
        locale: Locale,
        deleteClosure: @escaping MessageSheetCallback
    ) {
        let confirmationClosure: MessageSheetCallback = {
            let action = AlertPresentableAction(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.commonDeleteBackup(),
                style: .destructive,
                handler: deleteClosure
            )

            let viewModel = AlertPresentableViewModel(
                title: nil,
                message: R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupDeleteConfirmation(),
                actions: [action],
                closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
            )

            self.present(viewModel: viewModel, style: .actionSheet, from: view)
        }

        guard let deleteView = createMessageSheet(for: reason, confirmationClosure: confirmationClosure) else {
            return
        }

        view?.controller.present(deleteView.controller, animated: true)
    }
}
