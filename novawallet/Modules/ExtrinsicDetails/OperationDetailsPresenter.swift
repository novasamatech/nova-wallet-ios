import Foundation
import SoraFoundation

final class OperationDetailsPresenter {
    weak var view: OperationDetailsViewProtocol?
    let wireframe: OperationDetailsWireframeProtocol
    let interactor: OperationDetailsInteractorInputProtocol
    let viewModelFactory: OperationDetailsViewModelFactoryProtocol

    let chainAsset: ChainAsset

    private var model: OperationDetailsModel?

    init(
        interactor: OperationDetailsInteractorInputProtocol,
        wireframe: OperationDetailsWireframeProtocol,
        viewModelFactory: OperationDetailsViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let model = model else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(
            from: model,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension OperationDetailsPresenter: OperationDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension OperationDetailsPresenter: OperationDetailsInteractorOutputProtocol {
    func didReceiveDetails(result _: Result<OperationDetailsModel, Error>) {}
}

extension OperationDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
