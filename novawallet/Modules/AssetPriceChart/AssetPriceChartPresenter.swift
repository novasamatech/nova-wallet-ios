import Foundation
import Foundation_iOS

final class AssetPriceChartPresenter {
    weak var view: AssetPriceChartViewProtocol?
    weak var moduleOutput: AssetPriceChartModuleOutputProtocol?

    let interactor: AssetPriceChartInteractorInputProtocol
    let availablePeriods: [PriceHistoryPeriod]
    let placeholder: LocalizableResource<String>?
    let logger: Logger

    private let viewModelFactory: AssetPriceChartViewModelFactoryProtocol

    private var assetModel: AssetModel?
    private var locale: Locale
    private var selectedPeriod: PriceHistoryPeriod?
    private var chartState: AssetPriceChartState?
    private var priceData: PriceData?
    private var prices: [PriceHistoryPeriod: PriceHistory]?
    private var pricesByTime: [UInt64: Decimal]?

    private var hasHistory: Bool {
        prices?.values.contains { !$0.items.isEmpty } ?? false
    }

    init(
        interactor: AssetPriceChartInteractorInputProtocol,
        assetModel: AssetModel?,
        viewModelFactory: AssetPriceChartViewModelFactoryProtocol,
        periods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod?,
        placeholder: LocalizableResource<String>?,
        logger: Logger,
        locale: Locale
    ) {
        self.interactor = interactor
        self.assetModel = assetModel
        availablePeriods = periods
        self.viewModelFactory = viewModelFactory
        self.selectedPeriod = selectedPeriod.flatMap { periods.contains($0) ? $0 : nil } ?? periods.first
        self.placeholder = placeholder
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
            entries: prices?[selectedPeriod]?.items,
            availablePeriods: availablePeriods,
            selectedPeriod: selectedPeriod,
            priceData: priceData,
            availablePoints: Int(availablePoints),
            placeholder: assetModel == nil ? placeholder?.value(for: locale) : nil,
            locale: locale
        )
        let viewModel = viewModelFactory.createViewModel(params: params)

        view?.update(with: viewModel)
    }

    func provideChartState(_ state: AssetPriceChartState) {
        chartState = state

        view?.didReceive(chartState: state)
        moduleOutput?.didReceiveChartState(state)
    }

    func notifyIfChartAvailable() {
        guard hasHistory else { return }

        provideChartState(.available)
    }

    func resetChartData() {
        chartState = nil
        priceData = nil
        prices = nil
        pricesByTime = nil
    }
}

// MARK: AssetPriceChartPresenterProtocol

extension AssetPriceChartPresenter: AssetPriceChartPresenterProtocol {
    func setup() {
        if assetModel != nil {
            provideChartState(.loading)
        }

        interactor.setup()
        provideViewModel()
    }

    func selectPeriod(_ period: PriceHistoryPeriod) {
        selectedPeriod = period

        moduleOutput?.didSelectChartPeriod(period)

        if case .unavailable(.failed) = chartState {
            reload()
        } else {
            provideViewModel()
        }
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
            entries: prices?[selectedPeriod]?.items,
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
    func didReceive(prices: [PriceHistoryPeriod: PriceHistory]) {
        self.prices = prices
        pricesByTime = prices.values.reduce(into: [:]) { acc, values in
            values.items.forEach { acc[$0.startedAt] = $0.value }
        }

        if hasHistory {
            notifyIfChartAvailable()
        } else {
            provideChartState(.unavailable(.noHistory))
        }

        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        priceData = price

        notifyIfChartAvailable()
        provideViewModel()
    }

    func didReceive(_ error: AssetPriceChartInteractorError) {
        switch error {
        case .missingPriceId:
            provideChartState(.unavailable(.noHistory))
        case .chartDataNotAvailable,
             .priceDataNotAvailable:
            provideChartState(.unavailable(.failed))
        }

        logger.error("Failed presenting chart price data with error: \(error)")
    }
}

// MARK: AssetPriceChartModuleInputProtocol

extension AssetPriceChartPresenter: AssetPriceChartModuleInputProtocol {
    func updateLocale(_ newLocale: Locale) {
        locale = newLocale

        provideViewModel()
    }

    func updateSelectedCurrency(_ currency: Currency) {
        resetChartData()

        if assetModel != nil {
            provideChartState(.loading)
        }

        interactor.updateSelectedCurrency(currency)
        provideViewModel()
    }

    func updateAsset(_ asset: AssetModel?) {
        assetModel = asset
        resetChartData()

        if asset != nil {
            provideChartState(.loading)
        }

        interactor.updateAsset(asset)
        provideViewModel()
    }

    func reload() {
        guard assetModel != nil else { return }

        provideChartState(.loading)
        interactor.reload()
        provideViewModel()
    }
}
