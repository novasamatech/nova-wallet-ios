import Foundation
import UIKit_iOS

final class CloudBackupSettingsWireframe: CloudBackupSettingsWireframeProtocol {
    func showManualBackup(from view: CloudBackupSettingsViewProtocol?) {
        guard let manualBackupWalletListView = ManualBackupWalletListViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            manualBackupWalletListView.controller,
            animated: true
        )
    }

    func showCloudBackupReview(
        from view: CloudBackupSettingsViewProtocol?,
        changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate
    ) {
        guard
            let reviewChangesView = CloudBackupReviewChangesViewFactory.createView(
                for: changes,
                delegate: delegate
            ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        reviewChangesView.controller.modalTransitioningFactory = factory
        reviewChangesView.controller.modalPresentationStyle = .custom

        view?.controller.present(reviewChangesView.controller, animated: true)
    }

    func showWalletsRemoveConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale: Locale,
        onConfirm: @escaping () -> Void
    ) {
        let confirmationAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonApply(),
            handler: onConfirm
        )

        let viewModel = AlertPresentableViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.cloudBackupAlertRemoveWalletsTitle(),
            message: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.cloudBackupAlertRemoveWalletsMessage(),
            actions: [confirmationAction],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func showReviewUpdatesConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale _: Locale,
        onConfirm: @escaping () -> Void
    ) {
        guard
            let reviewUpdatesView = CloudBackupMessageSheetViewFactory.createUnsyncedChangesSheet(
                completionClosure: onConfirm,
                cancelClosure: nil
            ) else {
            return
        }

        view?.controller.present(reviewUpdatesView.controller, animated: true)
    }

    func showPasswordChangedConfirmation(
        on view: CloudBackupSettingsViewProtocol?,
        locale _: Locale,
        onConfirm: @escaping () -> Void
    ) {
        guard
            let passwordChangedView = CloudBackupMessageSheetViewFactory.createPasswordChangedSheet(
                completionClosure: onConfirm,
                cancelClosure: nil
            ) else {
            return
        }

        view?.controller.present(passwordChangedView.controller, animated: true)
    }

    func showEnterPassword(from view: CloudBackupSettingsViewProtocol?) {
        guard let enterPasswordView = ImportCloudPasswordViewFactory.createSetPasswordView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(enterPasswordView.controller, animated: true)
    }

    func showChangePassword(from view: CloudBackupSettingsViewProtocol?) {
        guard let changePasswordView = ImportCloudPasswordViewFactory.createChangePasswordView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(changePasswordView.controller, animated: true)
    }

    func showBackupCreation(from view: CloudBackupSettingsViewProtocol?) {
        guard let enableBackupView = CloudBackupCreateViewFactory.createViewForEnableBackup() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            enableBackupView.controller,
            animated: true
        )
    }
}
