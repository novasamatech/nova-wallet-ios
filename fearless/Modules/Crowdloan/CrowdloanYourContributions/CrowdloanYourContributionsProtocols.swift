import SoraFoundation

protocol CrowdloanYourContributionsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(contributions: [CrowdloanContributionViewModel])
}

protocol CrowdloanYourContributionsPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanYourContributionsVMFactoryProtocol: AnyObject {
    func createViewModel(
        for crowdloans: [Crowdloan],
        contributions: CrowdloanContributionDict,
        externalContributions: [ExternalContribution]?,
        displayInfo: CrowdloanDisplayInfoDict?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel
}

protocol CrowdloanYourContributionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CrowdloanYourContributionsInteractorOutputProtocol: AnyObject {
    func didReceiveExternalContributions(result: Result<[ExternalContribution], Error>)
}

protocol CrowdloanYourContributionsWireframeProtocol: AnyObject {}
