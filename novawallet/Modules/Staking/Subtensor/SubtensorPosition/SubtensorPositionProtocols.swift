import Foundation

protocol SubtensorPositionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPositionViewModel)
    func didReceive(priceHeader: SubtensorSubnetPriceHeaderViewModel)
}

protocol SubtensorPositionPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(at index: Int)
    func selectAction(_ action: SubtensorPositionAction)
    func selectValidator()
    func retrySync()
    func retryHistory()
    func selectChart(_ selection: SubtensorPriceChartSelection?)
}

protocol SubtensorPositionInteractorInputProtocol: AnyObject {
    func cachedPrices() -> SubtensorAlphaPrices?
    func cachedYields() -> SubtensorAlphaYields?
    func setup()
    func refreshPendingClaims()
    func refreshPositions()
    func loadPrices()
    func loadSubnetsInfo()
    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef)
    func loadRootHolds(for hotkeys: [AccountId])
    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod)
}

protocol SubnetPositionInteractorOutputProtocol: AnyObject {
    func didReceive(group: SubtensorPortfolioGroup?)
    func didReceiveSyncFailure(_ isFailed: Bool)
    func didReceive(price: PriceData?)
    func didChangeCurrency()
    func didReceive(prices: SubtensorAlphaPrices)
    func didFailPrices()
    func didReceive(subnetsInfo: SubtensorSubnetsInfo?)
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(validator: SubtensorValidatorDirectoryItem?, for hotkey: AccountId)
    func didFailValidator(for hotkey: AccountId)
    func didReceive(yields: SubtensorAlphaYields?)
    func didReceive(claimable: [SubtensorRootClaimPreview], isFailed: Bool)
    func didReceive(pendingClaimHotkeys: Set<AccountId>)
    func didReceive(holds: [AccountId: SubtensorRootHold], blockTime: BlockTime?)
    func didReceive(blockNumber: BlockNumber)
    func didReceive(history: SubtensorPriceHistory?, for period: SubtensorPricePeriod)
    func didFailHistory(for period: SubtensorPricePeriod)
    func didBecomeActive()
}

protocol SubtensorPositionWireframeProtocol: AnyObject, SubtensorOperationGating, SubtensorValidatorInfoPresentable {
    func showClaimRewards(from view: SubtensorPositionViewProtocol?, model: SubtensorClaimRewardsModel)
    func showAddStake(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition)
    func showBuyMore(from view: SubtensorPositionViewProtocol?, position: SubtensorStakingPosition)
    func showUnstake(from view: SubtensorPositionViewProtocol?, netuid: UInt16)
    func popToPortfolio(from view: SubtensorPositionViewProtocol?)
}
