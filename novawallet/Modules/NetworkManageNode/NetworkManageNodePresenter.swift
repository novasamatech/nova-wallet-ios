import Foundation

final class NetworkManageNodePresenter {
    weak var view: NetworkManageNodeViewProtocol?
    let wireframe: NetworkManageNodeWireframeProtocol
    let interactor: NetworkManageNodeInteractorInputProtocol

    init(
        interactor: NetworkManageNodeInteractorInputProtocol,
        wireframe: NetworkManageNodeWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NetworkManageNodePresenter: NetworkManageNodePresenterProtocol {
    func setup() {}
}

extension NetworkManageNodePresenter: NetworkManageNodeInteractorOutputProtocol {}