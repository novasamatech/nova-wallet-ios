import Foundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol
    let chainModel: ChainModel

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        chainModel: ChainModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainModel = chainModel
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {}
}

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {}
