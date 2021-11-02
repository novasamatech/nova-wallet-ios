import Foundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let input: CrowdloanYourContributionsViewInput
    let viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol

    init(
        input: CrowdloanYourContributionsViewInput,
        viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol,
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(
            for: input.crowdloans,
            contributions: input.contributions,
            displayInfo: input.displayInfo,
            chainAsset: input.chainAsset,
            locale: view?.selectedLocale ?? .current
        )
        view?.reload(contributions: viewModel.contributions)
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsPresenterProtocol {
    func setup() {
        updateView()
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {}
