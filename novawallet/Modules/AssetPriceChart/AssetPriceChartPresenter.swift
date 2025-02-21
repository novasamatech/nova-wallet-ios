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
        guard let selectedPeriod else { return }

        let viewModel = viewModelFactory.createViewModel(
            for: assetModel,
            entries: prices?[selectedPeriod],
            availablePeriods: availablePeriods,
            selectedPeriod: selectedPeriod,
            priceData: priceData,
            locale: locale
        )

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
        guard let entry, let selectedPeriod else {
            provideViewModel()
            return
        }

        let priceHistoryItem = PriceHistoryItem(
            startedAt: UInt64(entry.timestamp),
            value: entry.price
        )

        guard let viewModel = viewModelFactory.createPriceChangeViewModel(
            entries: prices?[selectedPeriod],
            priceData: priceData,
            lastEntry: priceHistoryItem,
            selectedPeriod: selectedPeriod,
            locale: locale
        ) else {
            return
        }

        view?.update(priceChange: viewModel)
    }
}

// MARK: AssetPriceChartInteractorOutputProtocol

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {
    func didReceive(prices: [PriceHistoryPeriod: [PriceHistoryItem]]) {
        self.prices = prices

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
