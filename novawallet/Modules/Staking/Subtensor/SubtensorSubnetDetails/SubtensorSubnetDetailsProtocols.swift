import Foundation

protocol SubtensorSubnetDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(title: SubtensorSubnetDetailsTitleViewModel)
    func didReceive(viewModel: SubtensorSubnetDetailsViewModel)
}

protocol SubtensorSubnetDetailsPresenterProtocol: AnyObject {
    func setup()
    func selectCurrency(at index: Int)
    func selectPeriod(at index: Int)
    func selectAmount(at index: Int)
    func toggleFavorite()
    func selectValidator()
    func useSubnet()
    func retryHistory()
}

protocol SubnetDetailsInteractorInputProtocol: AnyObject {
    func cachedSnapshot() -> SubtensorSubnetDetailsSnapshot
    func setup()
    func loadHistory(for period: SubtensorPricePeriod)
    func presetValidator(existingHotkey: AccountId?)
}

protocol SubnetDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveHistory(_ result: SubtensorPriceHistoryResult, for period: SubtensorPricePeriod)
    func didFailHistory(for period: SubtensorPricePeriod)
    func didReceiveListing(_ result: SubtensorPriceHistoryResult?)
    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?)
    func didReceivePreset(_ validator: SubtensorValidatorDirectoryItem?)
    func didReceiveYields(_ yields: SubtensorAlphaYields?)
    func didReceiveBalance(_ balance: AssetBalance?)
    func didReceiveTaoPrice(_ price: PriceData?)
    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?)
    func didReceivePositionsSyncFailed(_ isFailed: Bool)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
}

protocol SubtensorSubnetDetailsWireframeProtocol: AnyObject {
    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )

    func complete(
        from view: SubtensorSubnetDetailsViewProtocol?,
        host: SubtensorSubnetDetailsHost,
        target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        delegate: SubtensorSubnetSelectDelegate?
    )
}

struct SubtensorSubnetDetailsSnapshot {
    let rankingView: HTTPCachePeek<SubtensorRankedSubnets>
    let yields: HTTPCachePeek<SubtensorAlphaYields>
}
