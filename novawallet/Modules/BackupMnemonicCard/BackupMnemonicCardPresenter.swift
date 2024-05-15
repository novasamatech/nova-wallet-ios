import Foundation

final class BackupMnemonicCardPresenter {
    weak var view: BackupMnemonicCardViewProtocol?
    let wireframe: BackupMnemonicCardWireframeProtocol
    let interactor: BackupMnemonicCardInteractorInputProtocol

    init(
        interactor: BackupMnemonicCardInteractorInputProtocol,
        wireframe: BackupMnemonicCardWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension BackupMnemonicCardPresenter: BackupMnemonicCardPresenterProtocol {
    func setup() {}
}

extension BackupMnemonicCardPresenter: BackupMnemonicCardInteractorOutputProtocol {}
