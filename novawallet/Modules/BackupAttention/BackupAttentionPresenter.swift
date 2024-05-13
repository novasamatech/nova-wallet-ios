import Foundation

final class BackupAttentionPresenter {
    weak var view: BackupAttentionViewProtocol?
    let wireframe: BackupAttentionWireframeProtocol
    let interactor: BackupAttentionInteractorInputProtocol

    init(
        interactor: BackupAttentionInteractorInputProtocol,
        wireframe: BackupAttentionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension BackupAttentionPresenter: BackupAttentionPresenterProtocol {
    func setup() {}
}

extension BackupAttentionPresenter: BackupAttentionInteractorOutputProtocol {}