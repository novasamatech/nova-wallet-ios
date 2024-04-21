import Foundation

final class CloudBackupCreatePresenter {
    weak var view: CloudBackupCreateViewProtocol?
    let wireframe: CloudBackupCreateWireframeProtocol
    let interactor: CloudBackupCreateInteractorInputProtocol

    init(
        interactor: CloudBackupCreateInteractorInputProtocol,
        wireframe: CloudBackupCreateWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CloudBackupCreatePresenter: CloudBackupCreatePresenterProtocol {
    func setup() {}
}

extension CloudBackupCreatePresenter: CloudBackupCreateInteractorOutputProtocol {
    func didCreateWallet() {}

    func didReceive(error _: CloudBackupCreateInteractorError) {}
}
