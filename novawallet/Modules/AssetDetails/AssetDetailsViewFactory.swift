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

        let interactor = AssetDetailsInteractor(
            selectedMetaAccount: wallet,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            purchaseProvider: PurchaseAggregator.defaultAggregator(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )
        let wireframe = AssetDetailsWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let presenter = AssetDetailsPresenter(
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            localizableManager: LocalizationManager.shared,
            asset: asset,
            chain: chain,
            selectedAccountType: wallet.type,
            wireframe: wireframe
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
