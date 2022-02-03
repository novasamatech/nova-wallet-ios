import Foundation

final class AssetsManagePresenter {
    weak var view: AssetsManageViewProtocol?
    let wireframe: AssetsManageWireframeProtocol
    let interactor: AssetsManageInteractorInputProtocol

    init(
        interactor: AssetsManageInteractorInputProtocol,
        wireframe: AssetsManageWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AssetsManagePresenter: AssetsManagePresenterProtocol {
    func setup() {}
}

extension AssetsManagePresenter: AssetsManageInteractorOutputProtocol {}