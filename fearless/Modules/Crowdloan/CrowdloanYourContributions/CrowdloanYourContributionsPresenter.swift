import Foundation

final class CrowdloanYourContributionsPresenter {
    weak var view: CrowdloanYourContributionsViewProtocol?
    let wireframe: CrowdloanYourContributionsWireframeProtocol
    let interactor: CrowdloanYourContributionsInteractorInputProtocol

    init(
        interactor: CrowdloanYourContributionsInteractorInputProtocol,
        wireframe: CrowdloanYourContributionsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsPresenterProtocol {
    func setup() {}
}

extension CrowdloanYourContributionsPresenter: CrowdloanYourContributionsInteractorOutputProtocol {}
