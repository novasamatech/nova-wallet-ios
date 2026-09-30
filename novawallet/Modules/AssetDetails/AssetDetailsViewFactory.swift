import Foundation
import Foundation_iOS
import Keystore_iOS

struct AssetDetailsViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol
    ) -> AssetDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let selectedAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let interactor = createInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            swapState: swapState,
            currencyManager: currencyManager
        )

        let wireframe = AssetDetailsWireframe(
            operationState: operationState,
            swapState: swapState
        )
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
            ahmViewModelFactory: AHMInfoViewModelFactory(),
            viewModelFactory: viewModelFactory,
            wireframe: wireframe,
            logger: Logger.shared
        )

        guard let chartView = createChartView(
            asset: chainAsset.asset,
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

    private static func createInteractor(
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        swapState: SwapTokensFlowStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> AssetDetailsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let ahmInfoFactory = AHMFullInfoFactory(
            filterSetKeypath: \.ahmAssetDetailsAlertClosedChains
        )

        let bittensorEarnSource = AssetDetailsBittensorEarnSource(
            chainAsset: chainAsset,
            walletId: selectedAccount.metaId,
            stakingDashboardProviderFactory: StakingDashboardProviderFactory(
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                operationManager: OperationManagerFacade.sharedManager,
                logger: Logger.shared
            )
        )

        return AssetDetailsInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            ahmInfoFactory: ahmInfoFactory,
            settingsManager: SettingsManager.shared,
            selectedMetaAccount: selectedAccount,
            chainAsset: chainAsset,
            rampProvider: RampAggregator.defaultAggregator(),
            bittensorEarnSource: bittensorEarnSource,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactory.shared,
            swapState: swapState,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
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
