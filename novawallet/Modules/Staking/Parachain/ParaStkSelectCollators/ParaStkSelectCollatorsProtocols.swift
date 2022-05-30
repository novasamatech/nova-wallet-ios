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
}

protocol ParaStkSelectCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
}

protocol ParaStkSelectCollatorsWireframeProtocol: AlertPresentable, ErrorPresentable {
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
}

protocol ParaStkSelectCollatorsDelegate: AnyObject {
    func didSelect(collator: CollatorSelectionInfo)
}
