import Foundation

protocol SubtensorSubnetSelectDelegate: AnyObject {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget)
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget)
}

protocol SubtensorSubnetSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [SubtensorSubnetSelectViewModel])
    func didReceiveLoading(_ isLoading: Bool)
}

protocol SubtensorSubnetSelectPresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func select(viewModel: SubtensorSubnetSelectViewModel)
    func toggleFavorite(viewModel: SubtensorSubnetSelectViewModel)
    func selectSort(_ sort: SubtensorSubnetSort)
    func selectFilters(_ filters: SubtensorSubnetFilters)
}

enum SubtensorSubnetSort: CaseIterable, Equatable {
    case favorites
    case sevenDayChange
    case thirtyDayChange
    case poolDepth
    case volume
    case age
    case name
    case subnetNumber
}

struct SubtensorSubnetFilters: Equatable {
    var hideThinPools = false
    var onlyAboveThirtyDayAverage = false

    var isApplied: Bool { hideThinPools || onlyAboveThirtyDayAverage }
}

protocol SubnetSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func loadMonthlyMetrics(for info: SubtensorSubnetsInfo)
}

protocol SubnetSelectInteractorOutputProtocol: AnyObject {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo)
    func didReceiveDefaultTake(_ take: UInt16)
    func didReceiveWeeklyChanges(_ changes: [SubtensorSubnetRef: Decimal])
    func didReceiveMonthlyMetrics(_ metrics: [SubtensorSubnetRef: SubtensorMonthlyPriceMetrics])
    func didFailMonthlyMetrics()
    func didReceiveError(_ error: Error)
}

protocol SubtensorSubnetSelectWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func complete(from view: SubtensorSubnetSelectViewProtocol?)
    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        model: SubtensorSubnetSelectViewModel,
        delegate: SubtensorSubnetSelectDelegate
    )
}
