import Foundation
import NovaAnalytics

protocol SubtensorPortfolioViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel)
    func didReceive(header: SubtensorPortfolioHeaderViewModel)
    func didCompleteRefreshing()
}

protocol SubtensorPortfolioPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(at index: Int)
    func selectPosition(at index: Int)
    func addPosition()
    func retry()
    func refresh()
    func selectChartPoint(at index: Int?)
    func reopen(from source: StakingPortfolioSource)
}

protocol SubtensorPortfolioInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func refreshAll()
    func loadHistories(for period: SubtensorPricePeriod)
    func loadWeeklyChanges(for subnets: [SubtensorSubnetRef])
    func loadRootYields()
    func loadNetworkRootRate()
}

protocol SubtensorPortfolioInteractorOutputProtocol: AnyObject {
    func didReceive(state: Multistaking.SubtensorState)
    func didReceive(prices: SubtensorAlphaPrices?)
    func didReceive(subnetLogos: SubtensorSubnetLogos?)
    func didReceive(rootYields: SubtensorAlphaYields?)
    func didFailRootYields()
    func didReceive(networkRootRate: Decimal?)
    func didReceive(price: PriceData?)
    func didReceive(histories: SubtensorPortfolioPriceHistories)
    func didFailHistories(for period: SubtensorPricePeriod, error: Error?)
    func didReceive(weeklyChanges: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>])
    func didFailWeeklyChanges()
    func didReceiveSyncFailure(_ isFailed: Bool)
    func didReceivePositionsSyncing(_ isSyncing: Bool)
    func didChangeCurrency()
    func didReceiveAccountChange()
    func didBecomeActive()
    func didChangeStake()
}

protocol SubtensorPortfolioWireframeProtocol: AnyObject, FeatureSupportChecking, MessageSheetPresentable,
    SubtensorEarnInfoPresentable {
    func showPosition(from view: SubtensorPortfolioViewProtocol?, group: SubtensorPortfolioGroup)
    func showAddPosition(from view: SubtensorPortfolioViewProtocol?)
    func close(from view: SubtensorPortfolioViewProtocol?)
}
