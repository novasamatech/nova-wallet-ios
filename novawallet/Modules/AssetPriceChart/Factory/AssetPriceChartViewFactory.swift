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

        let interactor = AssetPriceChartInteractor(
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            asset: params.asset,
            currency: params.currency
        )
        let wireframe = AssetPriceChartWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = AssetPriceChartViewModelFactory(
            priceChangePercentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = AssetPriceChartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetModel: params.asset,
            viewModelFactory: viewModelFactory,
            periods: params.periods,
            logger: Logger.shared,
            locale: params.locale
        )

        let view = AssetPriceChartViewController(presenter: presenter)

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
        let periods: [PriceChartPeriod]
        let locale: Locale
        let currency: Currency
    }
}
