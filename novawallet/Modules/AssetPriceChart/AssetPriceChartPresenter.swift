import Foundation

final class AssetPriceChartPresenter {
    weak var view: AssetPriceChartViewProtocol?
    weak var moduleOutput: AssetPriceChartModuleOutputProtocol?

    let wireframe: AssetPriceChartWireframeProtocol
    let interactor: AssetPriceChartInteractorInputProtocol
    let assetModel: AssetModel
    let availablePeriods: [PriceChartPeriod]
    let logger: Logger

    private let viewModelFactory: AssetPriceChartViewModelFactoryProtocol

    private var locale: Locale
    private var selectedPeriod: PriceChartPeriod?
    private var priceData: PriceData?
    private var prices: [PriceChartPeriod: [CoingeckoChartSinglePriceData]]?

    init(
        interactor: AssetPriceChartInteractorInputProtocol,
        wireframe: AssetPriceChartWireframeProtocol,
        assetModel: AssetModel,
        viewModelFactory: AssetPriceChartViewModelFactoryProtocol,
        periods: [PriceChartPeriod],
        logger: Logger,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
            prices: prices?[selectedPeriod],
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

    func selectPeriod(_ period: PriceChartPeriod) {
        selectedPeriod = period

        provideViewModel()
    }

    func selectEntry(_ entry: AssetPriceChart.Entry?) {
        guard let entry, let selectedPeriod else {
            provideViewModel()
            return
        }

        guard let viewModel = viewModelFactory.createPriceChangeViewModel(
            prices: prices?[selectedPeriod],
            priceData: priceData,
            closingPrice: entry.price,
            locale: locale
        ) else {
            return
        }

        view?.update(priceChange: viewModel)
    }
}

// MARK: AssetPriceChartInteractorOutputProtocol

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {
    func didReceive(prices: [PriceChartPeriod: [CoingeckoChartSinglePriceData]]) {
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
