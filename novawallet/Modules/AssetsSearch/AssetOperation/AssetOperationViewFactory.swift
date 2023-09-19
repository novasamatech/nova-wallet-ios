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

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            for: operation,
            stateObservable: stateObservable,
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

        let view = createViewController(
            for: operation,
            presenter: presenter,
            title: title
        )
        presenter.view = view

        return view
    }

    private static func createViewController(
        for operation: TokenOperation,
        presenter: AssetsSearchPresenter,
        title: LocalizableResource<String>
    ) -> AssetsSearchViewController {
        switch operation {
        case .send:
            return SendAssetOperationViewController(
                presenter: presenter,
                keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: Set()),
                createViewClosure: { AssetsOperationViewLayout() },
                localizableTitle: title,
                localizationManager: LocalizationManager.shared
            )
        case .receive, .buy:
            return AssetsSearchViewController(
                presenter: presenter,
                keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: Set()),
                createViewClosure: { AssetsOperationViewLayout() },
                localizableTitle: title,
                localizationManager: LocalizationManager.shared
            )
        }
    }

    private static func createPresenter(
        for operation: TokenOperation,
        stateObservable: AssetListStateObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?
    ) -> AssetsSearchPresenter? {
        switch operation {
        case .send:
            return createSendPresenter(
                stateObservable: stateObservable,
                viewModelFactory: viewModelFactory,
                transferCompletion: transferCompletion
            )
        case .receive:
            guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
                return nil
            }

            return createReceivePresenter(
                stateObservable: stateObservable,
                viewModelFactory: viewModelFactory,
                wallet: selectedMetaAccount
            )
        case .buy:
            guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
                return nil
            }

            return createBuyPresenter(
                stateObservable: stateObservable,
                viewModelFactory: viewModelFactory,
                wallet: selectedMetaAccount
            )
        }
    }

    private static func createSendPresenter(
        stateObservable: AssetListStateObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?
    ) -> SendAssetOperationPresenter? {
        let filter: ChainAssetsFilter = { chainAsset in
            let assetMapper = CustomAssetMapper(type: chainAsset.asset.type, typeExtras: chainAsset.asset.typeExtras)

            guard let transfersEnabled = try? assetMapper.transfersEnabled() else {
                return false
            }

            return transfersEnabled
        }

        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: filter,
            logger: Logger.shared
        )

        let presenter = SendAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: SendAssetOperationWireframe(
                stateObservable: stateObservable,
                transferCompletion: transferCompletion
            )
        )

        interactor.presenter = presenter

        return presenter
    }

    private static func createReceivePresenter(
        stateObservable: AssetListStateObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) -> ReceiveAssetOperationPresenter? {
        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: nil,
            logger: Logger.shared
        )

        let presenter = ReceiveAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedAccount: wallet,
            wireframe: ReceiveAssetOperationWireframe()
        )

        interactor.presenter = presenter

        return presenter
    }

    private static func createBuyPresenter(
        stateObservable: AssetListStateObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) -> BuyAssetOperationPresenter? {
        let purchaseProvider = PurchaseAggregator.defaultAggregator()

        let filter: ChainAssetsFilter = { chainAsset in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return false
            }
            let purchaseActions = purchaseProvider.buildPurchaseActions(
                for: chainAsset,
                accountId: accountId
            )
            return !purchaseActions.isEmpty
        }

        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: filter,
            logger: Logger.shared
        )

        let presenter = BuyAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            selectedAccount: wallet,
            purchaseProvider: purchaseProvider,
            wireframe: BuyAssetOperationWireframe(),
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter

        return presenter
    }
}
