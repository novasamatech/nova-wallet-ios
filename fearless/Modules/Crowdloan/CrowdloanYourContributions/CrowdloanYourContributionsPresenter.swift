import Foundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let input: CrowdloanYourContributionsViewInput
    let viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol
    let logger: LoggerProtocol?

    private var externalContributions: [ExternalContribution]?

    init(
        input: CrowdloanYourContributionsViewInput,
        viewModelFactory: CrowdloanYourContributionsVMFactoryProtocol,
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.input = input
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(
            for: input.crowdloans,
            contributions: input.contributions,
            externalContributions: externalContributions,
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
        interactor.setup()
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {
    func didReceiveExternalContributions(result: Result<[ExternalContribution], Error>) {
        switch result {
        case let .success(contributions):
            let positiveContributions = contributions.filter { $0.amount > 0 }
            externalContributions = positiveContributions
            if !positiveContributions.isEmpty {
                updateView()
            }
        case let .failure(error):
            logger?.error("Did receive external contributions error: \(error)")
        }
    }
}
