import Foundation
import SoraFoundation

enum AssetOperationViewFactory {
    static func createBuyView(
        for stateObservable: AssetListStateObservable
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

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let presenter = createBuyPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            wallet: selectedMetaAccount
        )

        let title: LocalizableResource<String> = .init {
            R.string.localizable.assetOperationBuyTitle(preferredLanguages: $0.rLanguages)
        }

        let view = AssetsSearchViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: Set()),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    static func createReceiveView(
        for stateObservable: AssetListStateObservable
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

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let presenter = createReceivePresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            wallet: selectedMetaAccount
        )

        let title: LocalizableResource<String> = .init {
            R.string.localizable.assetOperationReceiveTitle(preferredLanguages: $0.rLanguages)
        }

        let view = AssetsSearchViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: Set()),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    static func createSendView(
        for stateObservable: AssetListStateObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
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

        let presenter = createSendPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let title: LocalizableResource<String> = .init {
            R.string.localizable.assetOperationSendTitle(preferredLanguages: $0.rLanguages)
        }

        let view = SendAssetOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: Set()),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    private static func createSendPresenter(
        stateObservable: AssetListStateObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?,
        buyTokensClosure: BuyTokensClosure?
    ) -> SendAssetOperationPresenter {
        let filter: ChainAssetsFilter = { chainAsset in
            return false
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
                buyTokensClosure: buyTokensClosure,
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
    ) -> ReceiveAssetOperationPresenter {
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
    ) -> BuyAssetOperationPresenter {
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
