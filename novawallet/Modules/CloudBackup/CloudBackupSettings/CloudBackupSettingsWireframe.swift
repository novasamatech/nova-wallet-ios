import Foundation
import SoraUI

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
}
