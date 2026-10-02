import Foundation

protocol SubtensorPositionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPositionViewModel)
}

protocol SubtensorPositionPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(at index: Int)
    func selectAction(_ action: SubtensorPositionAction)
    func selectValidator()
    func retrySync()
    func retryHistory()
}

protocol SubtensorPositionInteractorInputProtocol: AnyObject {
    func setup()
    func refreshPositions()
    func loadCatalogue()
    func loadSubnetsInfo(forcingRefresh: Bool)
    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadRootHolds(for hotkeys: [AccountId])
    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod)
}

protocol SubnetPositionInteractorOutputProtocol: AnyObject {
    func didReceive(group: SubtensorPortfolioGroup?)
    func didReceiveSyncFailure(_ isFailed: Bool)
    func didReceive(price: PriceData?)
    func didChangeCurrency()
    func didReceive(catalogue: SubtensorSubnetCatalogue?)
    func didReceive(subnetsInfo: SubtensorSubnetsInfo?)
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(validator: SubtensorValidatorDirectoryItem?, for hotkey: AccountId)
    func didReceive(rootRate: Decimal?)
    func didReceive(yields: SubtensorAlphaYields?)
    func didReceive(claimable: SubtensorRootClaimable?)
    func didReceiveClaimableFailure(_ isFailed: Bool)
    func didReceive(holds: [AccountId: SubtensorRootHold])
    func didReceive(blockNumber: BlockNumber)
    func didReceive(history: SubtensorPriceHistoryResult, for period: SubtensorPricePeriod)
    func didFailHistory(for period: SubtensorPricePeriod)
}

protocol SubtensorPositionWireframeProtocol: AnyObject, MessageSheetPresentable, SubtensorValidatorInfoPresentable {
    func showAddStake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition)
    func showBuyMore(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition)
    func showUnstake(from view: SubtensorPositionViewProtocol?, netuid: UInt16)
    func popToPortfolio(from view: SubtensorPositionViewProtocol?)
}
