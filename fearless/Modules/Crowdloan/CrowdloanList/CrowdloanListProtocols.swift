import SoraFoundation

protocol CrowdloanListViewProtocol: ControllerBackedProtocol {
    func didReceive(chainInfo: CrowdloansChainViewModel)
    func didReceive(listState: CrowdloanListState)
}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh(shouldReset: Bool)
    func selectCrowdloan(_ paraId: ParaId)
    func becomeOnline()
    func putOffline()
    func selectChain()
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
    func didReceiveContributions(result: Result<CrowdloanContributionDict, Error>)
    func didReceiveLeaseInfo(result: Result<ParachainLeaseInfoDict, Error>)
    func didReceiveSelectedChain(result: Result<ChainModel, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol CrowdloanListWireframeProtocol: AnyObject {
    func showYourContributions(
        crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        from view: ControllerBackedProtocol?
    )

    func presentContributionSetup(from view: CrowdloanListViewProtocol?, paraId: ParaId)
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?
    )
}
