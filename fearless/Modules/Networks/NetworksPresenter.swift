import Foundation
import RobinHood
import SoraFoundation
import IrohaCrypto

final class NetworksPresenter {
    weak var view: NetworksViewProtocol?
    let wireframe: NetworksWireframeProtocol
    let interactor: NetworksInteractorInputProtocol

    init(
        interactor: NetworksInteractorInputProtocol,
        wireframe: NetworksWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NetworksPresenter: NetworksPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension NetworksPresenter: NetworksInteractorOutputProtocol {}
