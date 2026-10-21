import Foundation

enum SubtensorSubnetSort: CaseIterable, Equatable {
    case poolDepth
    case age
    case apy
    case sevenDayChange
    case name
}

struct SubtensorSubnetFilters: Equatable {
    var hideThinPools = false

    var isApplied: Bool { hideThinPools }
}

protocol SubtensorSubnetSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(list: SubtensorSubnetListViewModel)
}

protocol SubtensorSubnetSelectPresenterProtocol: AnyObject {
    func setup()
    func becomeActive()
    func search(query: String)
    func selectSubnet(_ subnetRef: SubtensorSubnetRef)
    func toggleFavorite(_ subnetRef: SubtensorSubnetRef)
    func selectRoot()
    func showSort()
    func showFilters()
    func retry()
}

protocol SubtensorSubnetSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func refreshFavourites()
    func toggleFavorite(_ subnetRef: SubtensorSubnetRef)
    func loadWeeklyPrices(for subnets: [SubtensorSubnetRef])
    func loadApy()
}

protocol SubtensorSubnetSelectInteractorOutputProtocol: AnyObject {
    func didReceive(entries: [SubtensorSubnetListItem])
    func didReceive(favourites: Set<SubtensorSubnetRef>)
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>])
    func didReceive(apy: [UInt16: Decimal]?)
    func didReceiveError(_ error: Error)
}

protocol SubtensorSubnetSelectWireframeProtocol: AlertPresentable, ErrorPresentable,
    SubtensorSortSheetPresentable, SubtensorSubnetPickerCompleting {
    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        item: SubtensorSubnetListItem,
        abandonTracker: AnalyticsAbandonTracker?,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showFilters(
        from view: SubtensorSubnetSelectViewProtocol?,
        filters: SubtensorSubnetFilters,
        delegate: SubtensorSubnetFiltersDelegate
    )
}
