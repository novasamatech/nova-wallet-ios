protocol CollatorStakingSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CollatorSelectionState)
}

protocol CollatorStakingSelectPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func presentCollator(at index: Int)
    func selectCollator(at index: Int)
    func presentSearch()
    func presenterFilters()
    func clearFilters()
}

protocol CollatorStakingSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func retrySubscription()
}

protocol CollatorStakingSelectInteractorOutputProtocol: AnyObject {
    func didReceiveAllCollators(_ collators: [CollatorStakingSelectionInfoProtocol])
    func didReceiveCollatorsPref(_ collatorsPref: PreferredValidatorsProviderModel?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: CollatorStakingSelectInteractorError)
}

protocol CollatorStakingSelectWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func close(view: CollatorStakingSelectViewProtocol?)

    func showFilters(
        from view: CollatorStakingSelectViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: CollatorStakingSelectFiltersDelegate
    )

    func showSearch(
        from view: CollatorStakingSelectViewProtocol?,
        for collatorsInfo: [CollatorStakingSelectionInfoProtocol],
        delegate: CollatorStakingSelectDelegate
    )

    func showCollatorInfo(
        from view: CollatorStakingSelectViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    )
}

protocol CollatorStakingSelectDelegate: AnyObject {
    func didSelect(collator: CollatorStakingSelectionInfoProtocol)
}

enum CollatorStakingSelectInteractorError: Error {
    case allCollatorsFailed(Error)
    case preferredCollatorsFailed(Error)
    case priceFailed(Error)
}
