import Foundation
import Foundation_iOS
import UIKit_iOS

struct CloudBackupReviewChangesViewFactory {
    static func createView(
        for changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate
    ) -> CloudBackupReviewChangesViewProtocol? {
        let wireframe = CloudBackupReviewChangesWireframe()

        let viewModelFactory = CloudBackupReviewViewModelFactory()
        let presenter = CloudBackupReviewChangesPresenter(
            wireframe: wireframe,
            changes: changes,
            delegate: delegate,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupReviewChangesViewController(presenter: presenter)

        presenter.view = view

        let uiStatistics = viewModelFactory.estimateElementsCount(for: changes)

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        let estimatedHeight = CloudBackupReviewChangesViewController.estimateHeight(
            for: uiStatistics.sections,
            items: uiStatistics.items
        )

        let preferredContentSize = min(estimatedHeight, maxHeight)

        view.preferredContentSize = .init(width: 0, height: preferredContentSize)

        return view
    }
}
