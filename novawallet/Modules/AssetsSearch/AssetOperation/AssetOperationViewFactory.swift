import Foundation
import SoraFoundation

enum AssetOperationViewFactory {
    static func createView(
        for stateObservable: AssetListStateObservable,
        operation: TokenOperation,
        transferCompletion: TransferCompletionClosure?
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = AssetsSearchInteractor(stateObservable: stateObservable)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            for: operation,
            initState: stateObservable.state.value,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            transferCompletion: transferCompletion
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
        initState: AssetListState,
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?
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
                wireframe: SendAssetOperationWireframe(transferCompletion: transferCompletion)
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
