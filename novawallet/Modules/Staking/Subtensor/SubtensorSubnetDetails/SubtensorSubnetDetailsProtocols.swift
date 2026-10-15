import Foundation

protocol SubtensorSubnetDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(title: SubtensorSubnetDetailsTitleViewModel)
    func didReceive(viewModel: SubtensorSubnetDetailsViewModel)
    func didReceive(priceHeader: SubtensorSubnetPriceHeaderViewModel)
}

protocol SubtensorSubnetDetailsPresenterProtocol: AnyObject {
    func setup()
    func selectCurrency(at index: Int)
    func selectPeriod(at index: Int)
    func toggleFavorite()
    func selectValidator()
    func useSubnet()
    func retryHistory()
    func selectChart(_ selection: SubtensorPriceChartSelection?)
}

protocol SubnetDetailsInteractorInputProtocol: AnyObject {
    func cachedYields() -> SubtensorAlphaYields?
    func setup()
    func loadHistory(for period: SubtensorPricePeriod)
    func presetValidator(existingHotkey: AccountId?)
}

protocol SubnetDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveHistory(_ result: SubtensorPriceHistoryResult, for period: SubtensorPricePeriod)
    func didFailHistory(for period: SubtensorPricePeriod)
    func didReceiveParameters(_ parameters: SubtensorSubnetParameters?)
    func didReceivePreset(_ validator: SubtensorValidatorDirectoryItem?)
    func didReceiveYields(_ yields: SubtensorAlphaYields?)
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
