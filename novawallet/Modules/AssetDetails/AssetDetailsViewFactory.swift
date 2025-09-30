import Foundation
import Foundation_iOS
import Keystore_iOS

struct AssetDetailsViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol
    ) -> AssetDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let selectedAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let ahmInfoFactory = AHMFullInfoFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: AHMInfoRepository.shared
        )

        let interactor = AssetDetailsInteractor(
            ahmInfoFactory: ahmInfoFactory,
            settingsManager: SettingsManager.shared,
            selectedMetaAccount: selectedAccount,
            chainAsset: chainAsset,
            rampProvider: RampAggregator.defaultAggregator(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactory.shared,
            swapState: swapState,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )

        let wireframe = AssetDetailsWireframe(operationState: operationState, swapState: swapState)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = AssetDetailsViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            priceChangePercentFormatter: NumberFormatter.signedPercent.localizableResource()
        )

        let localizationManager = LocalizationManager.shared

        let presenter = AssetDetailsPresenter(
            interactor: interactor,
            localizableManager: localizationManager,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            viewModelFactory: viewModelFactory,
            wireframe: wireframe,
            logger: Logger.shared
        )

        guard let chartView = createChartView(
            asset: asset,
            locale: localizationManager.selectedLocale,
            currency: currencyManager.selectedCurrency,
            output: presenter,
            inputOwner: presenter
        ) else { return nil }

        let view = AssetDetailsViewController(
            chartViewProvider: chartView,
            presenter: presenter,
            localizableManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createChartView(
        asset: AssetModel,
        locale: Locale,
        currency: Currency,
        output: AssetPriceChartModuleOutputProtocol,
        inputOwner: AssetPriceChartInputOwnerProtocol
    ) -> AssetPriceChartModule? {
        let chartPeriods: [PriceHistoryPeriod] = [
            .day,
            .week,
            .month,
            .year,
            .allTime
        ]

        let chartParams = AssetPriceChartViewFactory.Params(
            asset: asset,
            periods: chartPeriods,
            locale: locale,
            currency: currency
        )

        return AssetPriceChartViewFactory.createView(
            output: output,
            inputOwner: inputOwner,
            params: chartParams
        )
    }
}
