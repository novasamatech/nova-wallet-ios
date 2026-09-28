import Foundation

struct SubtensorPortfolioRowViewModel {
    let group: SubtensorPortfolioGroup
    let title: String
    let amount: String
    let value: String?
    let subtitle: String
}

struct SubtensorPortfolioViewModel {
    let total: String
    let fiat: String?
    let rows: [SubtensorPortfolioRowViewModel]
    let syncFailed: Bool
}

protocol SubtensorPortfolioViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorPortfolioViewModel)
    func didReceiveChartLoading()
    func didReceive(series: SubtensorPortfolioValueSeries?)
}

protocol SubtensorPortfolioPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(_ period: SubtensorPricePeriod)
    func selectPosition(at index: Int)
    func addPosition()
    func retry()
}

protocol SubnetPortfolioInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
    func loadSeries(
        portfolio: SubtensorPortfolio,
        subnetsInfo: SubtensorSubnetsInfo?,
        priceId: String?,
        precision: Int16,
        period: SubtensorPricePeriod
    )
}

protocol SubnetPortfolioInteractorOutputProtocol: AnyObject {
    func didReceive(state: Multistaking.SubtensorStakingState)
    func didReceive(series: SubtensorPortfolioValueSeries?)
    func didReceiveSyncFailure(_ isFailed: Bool)
}

protocol SubtensorPortfolioWireframeProtocol: AnyObject {
    func showPosition(
        from view: SubtensorPortfolioViewProtocol?,
        group: SubtensorPortfolioGroup,
        state: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData
    )
    func showAddPosition(from view: SubtensorPortfolioViewProtocol?)
}
