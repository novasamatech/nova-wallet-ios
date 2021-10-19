import Foundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {}
}

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {}
