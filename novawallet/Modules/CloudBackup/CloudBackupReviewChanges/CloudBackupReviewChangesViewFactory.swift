import Foundation
import SoraFoundation

struct CloudBackupReviewChangesViewFactory {
    static func createView(
        for changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate
    ) -> CloudBackupReviewChangesViewProtocol? {
        let wireframe = CloudBackupReviewChangesWireframe()

        let presenter = CloudBackupReviewChangesPresenter(
            wireframe: wireframe,
            changes: changes,
            delegate: delegate,
            viewModelFactory: CloudBackupReviewViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupReviewChangesViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
