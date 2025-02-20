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
            prices: prices,
            availablePeriods: availablePeriods,
            selectedPeriod: selectedPeriod,
            for: assetModel,
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
        self.selectedPeriod = period
    }
}

// MARK: AssetPriceChartInteractorOutputProtocol

extension AssetPriceChartPresenter: AssetPriceChartInteractorOutputProtocol {
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
}

// STUB

private let prices: [CoingeckoChartSinglePriceData] = [
    CoingeckoChartSinglePriceData(timeStamp: 1_711_843_200_000, price: 69702.3087473573),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_846_800_000, price: 70123.4521684291),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_850_400_000, price: 69892.1845762934),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_854_000_000, price: 70356.2947583621),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_857_600_000, price: 70245.8374629158),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_861_200_000, price: 70892.4563781245),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_864_800_000, price: 71234.5678912345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_868_400_000, price: 71123.4567891234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_872_000_000, price: 60987.6543210987),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_875_600_000, price: 61345.6789123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_879_200_000, price: 41567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_882_800_000, price: 51789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_886_400_000, price: 51654.3210987654),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_890_000_000, price: 51432.1098765432),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_893_600_000, price: 51876.5432109876),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_897_200_000, price: 52098.7654321098),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_900_800_000, price: 52345.6789123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_904_400_000, price: 62123.4567891234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_908_000_000, price: 62456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_911_600_000, price: 42678.9012345678),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_915_200_000, price: 42901.2345678901),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_918_800_000, price: 42789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_922_400_000, price: 43012.3456789012),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_926_000_000, price: 43234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_929_600_000, price: 43456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_933_200_000, price: 48234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_936_800_000, price: 49567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_940_400_000, price: 53789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_944_000_000, price: 54567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_947_600_000, price: 56890.1234567890),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_951_200_000, price: 64123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_954_800_000, price: 64345.6789012345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_958_400_000, price: 64567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_962_000_000, price: 64789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_965_600_000, price: 64567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_969_200_000, price: 64890.1234567890),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_972_800_000, price: 65123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_976_400_000, price: 65345.6789012345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_980_000_000, price: 65123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_983_600_000, price: 65456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_987_200_000, price: 65678.9012345678),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_990_800_000, price: 70901.2345678901),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_994_400_000, price: 71789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_998_000_000, price: 72012.3456789012),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_001_600_000, price: 73234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_005_200_000, price: 71456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_008_800_000, price: 68234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_012_400_000, price: 62567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_016_000_000, price: 60789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_019_600_000, price: 59567.8901234567)
]
