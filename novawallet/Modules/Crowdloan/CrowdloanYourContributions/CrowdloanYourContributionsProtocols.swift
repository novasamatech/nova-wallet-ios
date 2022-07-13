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
    func didReceiveExternalContributions(_ externalContributions: [ExternalContribution])
    func didReceiveExternalCrowdloanFunds(_ funds: [ParaId: CrowdloanFunds])
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?)
    func didReceiveBlockDuration(_ blockDuration: BlockTime)
    func didReceiveLeasingPeriod(_ leasingPeriod: LeasingPeriod)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: Error)
}

protocol CrowdloanYourContributionsWireframeProtocol: AnyObject {}
