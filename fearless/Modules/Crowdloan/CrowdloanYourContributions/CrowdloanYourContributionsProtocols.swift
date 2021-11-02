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
        displayInfo: CrowdloanDisplayInfoDict?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel
}

protocol CrowdloanYourContributionsInteractorInputProtocol: AnyObject {}

protocol CrowdloanYourContributionsInteractorOutputProtocol: AnyObject {}

protocol CrowdloanYourContributionsWireframeProtocol: AnyObject {}
