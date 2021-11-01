import SoraFoundation

protocol CrowdloanYourContributionsViewProtocol: ControllerBackedProtocol {
    func reload(contributions: [CrowdloanContributionItem])
}

protocol CrowdloanYourContributionsPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanYourContributionsInteractorInputProtocol: AnyObject {}

protocol CrowdloanYourContributionsInteractorOutputProtocol: AnyObject {}

protocol CrowdloanYourContributionsWireframeProtocol: AnyObject {}
