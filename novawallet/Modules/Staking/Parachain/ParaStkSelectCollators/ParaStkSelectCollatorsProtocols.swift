protocol ParaStkSelectCollatorsViewProtocol: ControllerBackedProtocol {
    func didReceive(state: CollatorSelectionState)
}

protocol ParaStkSelectCollatorsPresenterProtocol: AnyObject {
    func setup()
    func refresh()
    func presentCollator(at index: Int)
    func selectCollator(at index: Int)
    func presentSearch()
    func presenterFilters()
    func clearFilters()
}

protocol ParaStkSelectCollatorsInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func retrySubscription()
}

protocol ParaStkSelectCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveAllCollators(_ collators: [CollatorSelectionInfo])
    func didReceiveCollatorsPref(_ collatorsPref: PreferredValidatorsProviderModel?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: ParaStkSelectCollatorsInteractorError)
}

protocol ParaStkSelectCollatorsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func close(view: ParaStkSelectCollatorsViewProtocol?)

    func showFilters(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for sorting: CollatorsSortType,
        delegate: ParaStkCollatorFiltersDelegate
    )

    func showSearch(
        from view: ParaStkSelectCollatorsViewProtocol?,
        for collatorsInfo: [CollatorSelectionInfo],
        delegate: ParaStkSelectCollatorsDelegate
    )

    func showCollatorInfo(
        from view: ParaStkSelectCollatorsViewProtocol?,
        collatorInfo: CollatorSelectionInfo
    )
}

protocol ParaStkSelectCollatorsDelegate: AnyObject {
    func didSelect(collator: CollatorSelectionInfo)
}

enum ParaStkSelectCollatorsInteractorError: Error {
    case allCollatorsFailed(Error)
    case preferredCollatorsFailed(Error)
    case priceFailed(Error)
}
