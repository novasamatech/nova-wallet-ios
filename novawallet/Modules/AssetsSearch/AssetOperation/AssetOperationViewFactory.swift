import Foundation
import SoraFoundation

enum AssetOperationViewFactory {
    static func createView(
        for initState: AssetListInitState,
        operation: TokenOperation
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

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            for: operation,
            initState: initState,
            interactor: interactor,
            viewModelFactory: viewModelFactory
        ) else {
            return nil
        }

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
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        for operation: TokenOperation,
        initState: AssetListInitState,
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol
    ) -> AssetsSearchPresenter? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }
        let localizationManager = LocalizationManager.shared

        switch operation {
        case .send:
            return SendAssetOperationPresenter(
                initState: initState,
                interactor: interactor,
                viewModelFactory: viewModelFactory,
                localizationManager: localizationManager,
                wireframe: SendAssetOperationWireframe()
            )
        case .receive:
            return ReceiveAssetOperationPresenter(
                initState: initState,
                interactor: interactor,
                viewModelFactory: viewModelFactory,
                localizationManager: localizationManager,
                selectedAccount: selectedMetaAccount,
                wireframe: ReceiveAssetOperationWireframe()
            )
        case .buy:
            return BuyAssetOperationPresenter(
                initState: initState,
                interactor: interactor,
                viewModelFactory: viewModelFactory,
                selectedAccount: selectedMetaAccount,
                purchaseProvider: PurchaseAggregator.defaultAggregator(),
                wireframe: BuyAssetOperationWireframe(),
                localizationManager: localizationManager
            )
        }
    }
}
