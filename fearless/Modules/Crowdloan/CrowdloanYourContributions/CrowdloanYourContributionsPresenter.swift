import Foundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol
    let contributions: [CrowdloanContributionItem]

    init(
        contributions: [CrowdloanContributionItem],
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol
    ) {
        self.contributions = contributions
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func updateView() {
        view?.reload(contributions: contributions)
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsPresenterProtocol {
    func setup() {
        updateView()
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {}
