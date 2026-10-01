import Foundation

enum SubtensorSubnetSort: CaseIterable, Equatable {
    case sevenDayChange
    case poolDepth
    case age
    case name
}

struct SubtensorSubnetFilters: Equatable {
    var hideThinPools = false

    var isApplied: Bool { hideThinPools }
}

protocol SubtensorSubnetSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(list: SubtensorSubnetListViewModel)
    func didReceive(rootBar: SubtensorStakeToRootBarViewModel)
}

protocol SubtensorSubnetFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorSubnetFiltersViewModel)
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
    func draftFilters(_ filters: SubtensorSubnetFilters)
    func applyFilters(_ filters: SubtensorSubnetFilters)
}

protocol SubnetSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func loadWeeklyPrices(for subnets: [SubtensorSubnetRef])
}

protocol SubnetSelectInteractorOutputProtocol: AnyObject {
    func didReceive(entries: [SubtensorSubnetListEntry])
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(rootRate: Decimal?)
    func didReceive(rankedSubnets: SubtensorRankedSubnets?)
    func didReceive(weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>])
    func didReceiveError(_ error: Error)
}

protocol SubtensorSubnetSelectWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    SubtensorSortSheetPresentable, SubtensorSubnetPickerCompleting {
    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        item: SubtensorSubnetListItem,
        delegate: SubtensorSubnetSelectDelegate
    )

    func showFilters(
        from view: SubtensorSubnetSelectViewProtocol?,
        viewModel: SubtensorSubnetFiltersViewModel,
        onChange: @escaping (SubtensorSubnetFilters) -> Void,
        onApply: @escaping (SubtensorSubnetFilters) -> Void
    ) -> SubtensorSubnetFiltersViewProtocol?
}
