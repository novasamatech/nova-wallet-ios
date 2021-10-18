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
        let viewModel = NetworksViewModel(
            sections: [
                (.supported, [
                    .init(name: "Polkadot", icon: nil, nodeDescription: "Auto select nodes"),
                    .init(name: "Kusama", icon: nil, nodeDescription: "Auto select nodes"),
                ]),
                (.testnets, [
                    .init(name: "Westend", icon: nil, nodeDescription: "Auto")
                ])
            ]
        )
        let state = NetworksViewState.loaded(viewModel)
        view?.reload(state: state)
    }
}

extension NetworksPresenter: NetworksInteractorOutputProtocol {}
