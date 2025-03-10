import Foundation

struct AssetPriceChartViewFactory {
    static func createView(
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol,
        params: Params
    ) -> AssetPriceChartModule? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let priceChartDataOperationFactory = PriceChartDataOperationFactory(
            fetchOperationFactory: CoingeckoOperationFactory(),
            availablePeriods: params.periods
        )

        let interactor = AssetPriceChartInteractor(
            priceChartDataOperationFactory: priceChartDataOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            asset: params.asset,
            operationQueue: operationQueue,
            currency: params.currency
        )

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = AssetPriceChartViewModelFactory(
            priceChangePercentFormatter: NumberFormatter.percent.localizableResource(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let logger = Logger.shared

        let presenter = AssetPriceChartPresenter(
            interactor: interactor,
            assetModel: params.asset,
            viewModelFactory: viewModelFactory,
            periods: params.periods,
            logger: logger,
            locale: params.locale
        )

        let seekHapticPlayer = HapticPlayerFactory.createProgressivePlayer(
            patternConfiguration: .chartSeek
        )
        let singleTapHapticPlayer = HapticPlayerFactory.createHapticPlayer(
            patternConfiguration: .singleTap
        )

        let view = AssetPriceChartViewController(
            presenter: presenter,
            seekHapticPlayer: seekHapticPlayer,
            chartLongPressHapticPlayer: singleTapHapticPlayer,
            periodControlHapticPlayer: singleTapHapticPlayer
        )

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.assetPriceChartModule = presenter

        return view
    }
}

extension AssetPriceChartViewFactory {
    struct Params {
        let asset: AssetModel
        let periods: [PriceHistoryPeriod]
        let locale: Locale
        let currency: Currency
    }
}
