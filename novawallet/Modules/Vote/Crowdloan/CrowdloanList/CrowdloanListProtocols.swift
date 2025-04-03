import Foundation_iOS

protocol CrowdloansViewProtocol: AlertPresentable, ControllerBackedProtocol, LoadableViewProtocol {
    var presenter: CrowdloanListPresenterProtocol? { get set }

    func didReceive(chainInfo: ChainBalanceViewModel)
    func didReceive(listState: CrowdloansViewModel)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func refresh(shouldReset: Bool)
    func selectCrowdloan(_ paraId: ParaId)
    func handleYourContributions()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func saveSelected(chainModel: ChainModel)
    func becomeOnline()
    func putOffline()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<[Crowdloan], Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfoDict, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveLeasingOffset(result: Result<LeasingOffset, Error>)
    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>)
    func didReceiveExternalContributions(result: Result<[ExternalContribution], Error>)
    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>)
    func didReceiveSelectedChain(result: Result<ChainModel, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>?)
}

protocol CrowdloanListWireframeProtocol: AlertPresentable, NoAccountSupportPresentable {
    func presentContributionSetup(
        from view: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?,
        crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?
    )

    func showYourContributions(
        crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        from view: ControllerBackedProtocol?
    )

    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: ChainAssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )

    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel)
}
