import Foundation

enum CloudBackupDeleteReason {
    case forgotPassword
    case brokenOrEmpty
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
    func showCloudBackupDelete(
        from view: ControllerBackedProtocol?,
        reason: CloudBackupDeleteReason,
        locale: Locale,
        deleteClosure: @escaping MessageSheetCallback
    ) {
        let confirmationClosure: MessageSheetCallback = {
            let action = AlertPresentableAction(
                title: R.string.localizable.commonDeleteBackup(
                    preferredLanguages: locale.rLanguages
                ),
                style: .destructive,
                handler: deleteClosure
            )

            let viewModel = AlertPresentableViewModel(
                title: nil,
                message: R.string.localizable.cloudBackupDeleteConfirmation(
                    preferredLanguages: locale.rLanguages
                ),
                actions: [action],
                closeAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
            )

            self.present(viewModel: viewModel, style: .actionSheet, from: view)
        }

        let optDeleteView: MessageSheetViewProtocol? = switch reason {
        case .forgotPassword:
            CloudBackupMessageSheetViewFactory.createNoOrForgotPassword(
                deleteClosure: confirmationClosure,
                cancelClosure: nil
            )
        case .brokenOrEmpty:
            CloudBackupMessageSheetViewFactory.createEmptyOrBrokenBackup(
                deleteClosure: confirmationClosure,
                cancelClosure: nil
            )
        }

        guard let deleteView = optDeleteView else {
            return
        }

        view?.controller.present(deleteView.controller, animated: true)
    }
}
