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
    func selectLink(_ url: URL)
}

protocol SubtensorSubnetDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func loadParameters()
    func loadHistory(for period: SubtensorPricePeriod, registrationDate: Date?)
    func toggleFavorite()
    func presetValidator(existingHotkey: AccountId?)
}

protocol SubtensorSubnetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(isFavorite: Bool)
    func didReceiveHistory(_ history: SubtensorPriceHistory?, for period: SubtensorPricePeriod)
    func didFailHistory(for period: SubtensorPricePeriod, error: Error)
    func didReceiveParameters(_ parameters: SubtensorSubnetParameters)
    func didFailParameters()
    func didReceivePreset(_ validator: SubtensorValidatorDirectoryItem?)
    func didFailPreset()
    func didReceiveYields(_ yields: SubtensorAlphaYields?)
    func didReceiveTaoPrice(_ price: PriceData?)
    func didChangeCurrency()
    func didReceivePositions(_ state: Multistaking.SubtensorState?)
    func didReceivePositionsSyncFailed(_ isFailed: Bool)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?)
    func didBecomeActive()
}

protocol SubtensorSubnetDetailsWireframeProtocol: WebPresentable, SubtensorSubnetPickerCompleting,
    SubtensorCallerPopping {
    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        recommendedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    )
}
