import Foundation
import SoraFoundation

struct AssetsSearchViewFactory {
    static func createView(
        for initState: AssetListInitState,
        delegate: AssetsSearchDelegate
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let interactor = AssetsSearchInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        let presenter = AssetsSearchPresenter(
            initState: initState,
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = AssetsSearchViewController(
            presenter: presenter,
            createViewClosure: { AssetsSearchViewLayout() },
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createView(
        for initState: AssetListInitState,
        operation: TokenOperation
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared,
              let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let interactor = AssetsSearchInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            logger: Logger.shared
        )

        let wireframe = AssetOperationWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        let localizationManager = LocalizationManager.shared

        let searchPresenter = AssetsSearchPresenter(
            initState: initState,
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let presenter = AssetOperationPresenter(
            operation: operation,
            selectedAccount: selectedMetaAccount,
            searchPresenter: searchPresenter,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        let title: LocalizableResource<String> = .init {
            let languages = $0.rLanguages
            switch operation {
            case .send:
                return R.string.localizable.assetOperationSendTitle(preferredLanguages: languages)
            case .receive:
                return R.string.localizable.assetOperationReceiveTitle(preferredLanguages: languages)
            case .buy:
                return R.string.localizable.assetOperationBuyTitle(preferredLanguages: languages)
            }
        }

        let view = AssetsSearchViewController(
            presenter: presenter,
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: localizationManager
        )

        searchPresenter.view = view
        interactor.presenter = searchPresenter

        return view
    }
}
