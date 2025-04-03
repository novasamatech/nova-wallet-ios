import Foundation
import Foundation_iOS

final class CloudBackupReviewChangesPresenter {
    weak var view: CloudBackupReviewChangesViewProtocol?
    let wireframe: CloudBackupReviewChangesWireframeProtocol

    let changes: CloudBackupSyncResult.Changes

    let viewModelFactory: CloudBackupReviewViewModelFactoryProtocol

    weak var delegate: CloudBackupReviewChangesDelegate?

    init(
        wireframe: CloudBackupReviewChangesWireframeProtocol,
        changes: CloudBackupSyncResult.Changes,
        delegate: CloudBackupReviewChangesDelegate,
        viewModelFactory: CloudBackupReviewViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.changes = changes
        self.delegate = delegate
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModels = viewModelFactory.createViewModels(
            from: changes,
            locale: selectedLocale
        )

        view?.didReceive(viewModels: viewModels)
    }
}

extension CloudBackupReviewChangesPresenter: CloudBackupReviewChangesPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func activateNotNow() {
        wireframe.close(view: view, closure: nil)
    }

    func activateApply() {
        wireframe.close(view: view) {
            self.delegate?.cloudBackupReviewerDidApprove(changes: self.changes)
        }
    }
}

extension CloudBackupReviewChangesPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
