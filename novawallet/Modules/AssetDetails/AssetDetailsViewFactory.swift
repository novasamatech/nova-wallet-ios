import Foundation
import SoraFoundation

struct AssetDetailsViewFactory {
    static func createView(chain: ChainModel, asset: AssetModel) -> AssetDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let interactor = AssetDetailsInteractor(
            selectedMetaAccount: wallet,
            chainAsset: chainAsset,
            purchaseProvider: PurchaseAggregator.defaultAggregator(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactory.shared,
            currencyManager: currencyManager
        )
        let wireframe = AssetDetailsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let balanceFormatterFactory = AssetBalanceFormatterFactory()
        let tokenFormatter = balanceFormatterFactory.createTokenFormatter(for: asset.displayInfo)
        let viewModelFactory = AssetDetailsViewModelFactory(balanceViewModelFactory: balanceFormatterFactory,
                                                            amountFormatter: tokenFormatter,
                                                            priceFormatter: tokenFormatter,
                                                            networkViewModelFactory: NetworkViewModelFactory(),
                                                            priceChangePercentFormatter: NumberFormatter.signedPercent.localizableResource())
        
        let presenter = AssetDetailsPresenter(
            interactor: interactor,
            localizableManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            selectedAccountType: wallet.type,
            viewModelFactory: AssetDetailsViewModelFactoryProtocol,
            wireframe: wireframe,
            logger: Logger.shared
        )
  
        let view = AssetDetailsViewController(
            presenter: presenter,
            localizableManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
