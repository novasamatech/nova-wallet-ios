import Foundation
import Foundation_iOS

struct AssetPriceChartViewFactory {
    static func createView(
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol,
        params: Params
    ) -> AssetPriceChartModule? {
        createController(
            output: output,
            inputOwner: inputOwner,
            params: params,
            style: .regular
        )
    }

    static func createCompactView(
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol,
        params: Params
    ) -> AssetPriceChartCompactProviderProtocol? {
        createController(
            output: output,
            inputOwner: inputOwner,
            params: params,
            style: .compact
        )
    }
}

private extension AssetPriceChartViewFactory {
    static func createController(
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol,
        params: Params,
        style: AssetPriceChartStyle
    ) -> AssetPriceChartViewController? {
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
            selectedPeriod: params.selectedPeriod,
            placeholder: params.placeholder,
            logger: logger,
            locale: params.locale
        )

        let view = createViewController(presenter: presenter, style: style)

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.assetPriceChartModule = presenter

        return view
    }

    static func createViewController(
        presenter: AssetPriceChartPresenterProtocol,
        style: AssetPriceChartStyle
    ) -> AssetPriceChartViewController {
        let seekHapticPlayer = HapticPlayerFactory.createProgressivePlayer(
            patternConfiguration: .chartSeek
        )
        let singleTapHapticPlayer = HapticPlayerFactory.createHapticPlayer(
            patternConfiguration: .singleTap
        )

        return AssetPriceChartViewController(
            presenter: presenter,
            style: style,
            seekHapticPlayer: seekHapticPlayer,
            chartLongPressHapticPlayer: singleTapHapticPlayer,
            periodControlHapticPlayer: singleTapHapticPlayer
        )
    }
}

extension AssetPriceChartViewFactory {
    struct Params {
        let asset: AssetModel?
        let periods: [PriceHistoryPeriod]
        var selectedPeriod: PriceHistoryPeriod?
        var placeholder: LocalizableResource<String>?
        let locale: Locale
        let currency: Currency
    }
}
