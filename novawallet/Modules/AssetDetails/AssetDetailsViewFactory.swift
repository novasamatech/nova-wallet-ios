import Foundation
import SoraFoundation

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

        let interactor = AssetDetailsInteractor(
            selectedMetaAccount: selectedAccount,
            chainAsset: chainAsset,
            purchaseProvider: PurchaseAggregator.defaultAggregator(),
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

        guard let chartView = AssetPriceChartViewFactory.createView(
            asset: chainAsset.asset,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
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
}
