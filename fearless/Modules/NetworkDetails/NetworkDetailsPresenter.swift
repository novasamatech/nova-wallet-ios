import Foundation
import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol
    let viewModelFactory: NetworkDetailsViewModelFactoryProtocol
    let chainModel: ChainModel
    let localizationManager: LocalizationManagerProtocol?

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        viewModelFactory: NetworkDetailsViewModelFactoryProtocol,
        chainModel: ChainModel,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainModel = chainModel
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(chainModel: chainModel, locale: selectedLocale)
        view?.reload(viewModel: viewModel)
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        updateView()
    }
}

extension NetworkDetailsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {}
