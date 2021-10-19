import Foundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol
    let viewModelFactory: NetworkDetailsViewModelFactoryProtocol
    let chainModel: ChainModel

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        viewModelFactory: NetworkDetailsViewModelFactoryProtocol,
        chainModel: ChainModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainModel = chainModel
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViewModel(chainModel: chainModel)
        view?.reload(viewModel: viewModel)
    }
}

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {}
