import Foundation

final class AssetPriceChartPresenter {
    weak var view: AssetPriceChartViewProtocol?
    weak var moduleOutput: AssetPriceChartModuleOutputProtocol?

    let interactor: AssetPriceChartInteractorInputProtocol
    let assetModel: AssetModel
    let availablePeriods: [PriceHistoryPeriod]
    let logger: Logger

    private let viewModelFactory: AssetPriceChartViewModelFactoryProtocol

    private var locale: Locale
    private var selectedPeriod: PriceHistoryPeriod?
    private var priceData: PriceData?
    private var prices: [PriceHistoryPeriod: [PriceHistoryItem]]?
    private var pricesByTime: [UInt64: Decimal]?

    init(
        interactor: AssetPriceChartInteractorInputProtocol,
        assetModel: AssetModel,
        viewModelFactory: AssetPriceChartViewModelFactoryProtocol,
        periods: [PriceHistoryPeriod],
        logger: Logger,
        locale: Locale
    ) {
        self.interactor = interactor
        self.assetModel = assetModel
        availablePeriods = periods
        self.viewModelFactory = viewModelFactory
        selectedPeriod = periods.first
        self.logger = logger
        self.locale = locale
    }
}

// MARK: Private

private extension AssetPriceChartPresenter {
    func provideViewModel() {
        guard
            let selectedPeriod,
            let availablePoints = view?.chartViewWidth()
        else { return }

        let params = PriceChartWidgetFactoryParams(
            asset: assetModel,
            entries: prices?[selectedPeriod],
            availablePeriods: availablePeriods,
            selectedPeriod: selectedPeriod,
            priceData: priceData,
            availablePoints: Int(availablePoints),
            locale: locale
        )
        let viewModel = viewModelFactory.createViewModel(params: params)

        view?.update(with: viewModel)
    }
}

// MARK: AssetPriceChartPresenterProtocol

extension AssetPriceChartPresenter: AssetPriceChartPresenterProtocol {
    func setup() {
        interactor.setup()

        provideViewModel()
    }

    func selectPeriod(_ period: PriceHistoryPeriod) {
        selectedPeriod = period

        provideViewModel()
    }

    func selectEntry(_ entry: AssetPriceChart.Entry?) {
        guard
            let entry,
            let historyItemPrice = pricesByTime?[UInt64(entry.timestamp)],
            let selectedPeriod
        else {
            provideViewModel()
            return
        }

        let historyItem = PriceHistoryItem(
            startedAt: UInt64(entry.timestamp),
            value: historyItemPrice
        )

        let params = PriceChartPriceUpdateViewFactoryParams(
            entries: prices?[selectedPeriod],
            priceData: priceData,
            lastEntry: historyItem,
            selectedPeriod: selectedPeriod,
            locale: locale
        )
        guard let viewModel = viewModelFactory.createPriceUpdateViewModel(params: params) else {
            return
        }

        view?.update(with: viewModel)
    }
}

// MARK: AssetPriceChartInteractorOutputProtocol

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {
    func didReceive(prices: [PriceHistoryPeriod: [PriceHistoryItem]]) {
        self.prices = prices
        pricesByTime = prices.values.reduce(into: [:]) { acc, values in
            values.forEach { acc[$0.startedAt] = $0.value }
        }

        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        priceData = price

        provideViewModel()
    }

    func didReceive(_ error: Error) {
        moduleOutput?.didReceive(error)
    }
}

// MARK: AssetPriceChartModuleInputProtocol

extension AssetPriceChartPresenter: AssetPriceChartModuleInputProtocol {
    func updateLocale(_ newLocale: Locale) {
        locale = newLocale

        provideViewModel()
    }

    func updateSelectedCurrency(_ currency: Currency) {
        interactor.updateSelectedCurrency(currency)
    }
}
