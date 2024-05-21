import Foundation

final class ManualBackupKeyListPresenter {
    weak var view: ManualBackupKeyListViewProtocol?
    let wireframe: ManualBackupKeyListWireframeProtocol
    let interactor: ManualBackupKeyListInteractorInputProtocol

    init(
        interactor: ManualBackupKeyListInteractorInputProtocol,
        wireframe: ManualBackupKeyListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ManualBackupKeyListPresenter: ManualBackupKeyListPresenterProtocol {
    func setup() {}
}

extension ManualBackupKeyListPresenter: ManualBackupKeyListInteractorOutputProtocol {}