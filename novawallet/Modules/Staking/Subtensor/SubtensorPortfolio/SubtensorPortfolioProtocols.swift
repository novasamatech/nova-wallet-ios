import Foundation

protocol SubtensorPortfolioViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel)
    func didReceive(header: SubtensorPortfolioHeaderViewModel)
}

protocol SubtensorPortfolioPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(at index: Int)
    func selectPosition(at index: Int)
    func addPosition()
    func retry()
    func selectChartPoint(at index: Int?)
}

protocol SubnetPortfolioInteractorInputProtocol: AnyObject {
    func cachedSnapshot() -> SubtensorPortfolioSnapshot
    func setup()
    func refresh()
    func loadHistories(for period: SubtensorPricePeriod, subnets: [SubtensorSubnetRef])
    func loadWeeklyChanges(for subnets: [SubtensorSubnetRef])
}

protocol SubnetPortfolioInteractorOutputProtocol: AnyObject {
    func didReceive(state: Multistaking.SubtensorStakingState)
    func didReceive(catalogue: SubtensorSubnetCatalogue?)
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(rootRate: Decimal?)
    func didReceive(price: PriceData?)
    func didReceive(histories: SubtensorPortfolioPriceHistories)
    func didFailHistories(for period: SubtensorPricePeriod)
    func didReceive(weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>])
    func didReceiveSyncFailure(_ isFailed: Bool)
    func didChangeCurrency()
    func didReceiveAccountChange()
}

protocol SubtensorPortfolioWireframeProtocol: AnyObject, MessageSheetPresentable, SubtensorEarnInfoPresentable {
    func showPosition(from view: SubtensorPortfolioViewProtocol?, group: SubtensorPortfolioGroup)
    func showAddPosition(from view: SubtensorPortfolioViewProtocol?)
    func close(from view: SubtensorPortfolioViewProtocol?)
}

struct SubtensorPortfolioSnapshot {
    let catalogue: HTTPCachePeek<SubtensorSubnetCatalogue>
    let rootRate: HTTPCachePeek<Decimal?>
}
