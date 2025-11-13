import Foundation
import Foundation_iOS
import Keystore_iOS

enum AssetOperationViewFactory {
    // MARK: - RAMP

    static func createRampView(
        for stateObservable: AssetListModelObservable,
        action: RampActionType,
        delegate: RampFlowStartingDelegate?
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let chainAssetViewModelFactory = ChainAssetViewModelFactory()

        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            currencyManager: currencyManager
        )

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let rampProvider = RampAggregator.defaultAggregator()
        let wireframe = RampAssetOperationWireframe(
            delegate: delegate,
            stateObservable: stateObservable
        )

        let presenterDependenciess = RampPresenterDependencies(
            stateObservable: stateObservable,
            selectedAccount: selectedMetaAccount,
            rampProvider: rampProvider,
            rampType: action,
            currencyManager: currencyManager,
            viewModelFactory: viewModelFactory,
            wireframe: wireframe
        )

        let presenter = createRampPresenter(
            dependencies: presenterDependenciess,
            flowStartingDelegate: delegate
        )

        let title: LocalizableResource<String> = switch action {
        case .offRamp: .init { R.string(preferredLanguages: $0.rLanguages).localizable.assetOperationSellTitle() }
        case .onRamp: .init { R.string(preferredLanguages: $0.rLanguages).localizable.assetOperationBuyTitle() }
        }

        let view = AssetOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: ModalNavigationKeyboardStrategy(),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    // MARK: - RECEIVE

    static func createReceiveView(
        for stateObservable: AssetListModelObservable
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let chainAssetViewModelFactory = ChainAssetViewModelFactory()

        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
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
            R.string(preferredLanguages: $0.rLanguages).localizable.assetOperationReceiveTitle()
        }

        let view = AssetOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: ModalNavigationKeyboardStrategy(),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    // MARK: - SEND

    static func createSendView(
        for stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let chainAssetViewModelFactory = ChainAssetViewModelFactory()

        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            currencyManager: currencyManager
        )

        let presenter = createSendPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let title: LocalizableResource<String> = .init {
            R.string(preferredLanguages: $0.rLanguages).localizable.assetOperationSendTitle()
        }

        let view = SendAssetOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: ModalNavigationKeyboardStrategy(),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    // MARK: - GIFT

    static func createGiftView(
        for stateObservable: AssetListModelObservable,
        transferCompletion: @escaping TransferCompletionClosure,
        buyTokensClosure: @escaping BuyTokensClosure
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let chainAssetViewModelFactory = ChainAssetViewModelFactory()

        let viewModelFactory = AssetListAssetViewModelFactory(
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            currencyManager: currencyManager
        )

        let presenter = createGiftPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            transferCompletion: transferCompletion,
            buyTokensClosure: buyTokensClosure
        )

        let title: LocalizableResource<String> = .init {
            R.string(preferredLanguages: $0.rLanguages).localizable.assetOperationGiftTitle()
        }

        let view = AssetOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: ModalNavigationKeyboardStrategy(),
            createViewClosure: { AssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}

// MARK: - Private

private extension AssetOperationViewFactory {
    static func createGiftPresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?,
        buyTokensClosure: BuyTokensClosure?
    ) -> GiftAssetOperationPresenter {
        let filter = AssetOperationChainAssetFilterFactory.createGiftAssetFilter()

        let assetTransferAggregationFactory = AssetTransferAggregationFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let interactor = GiftAssetsOperationInteractor(
            stateObservable: stateObservable,
            filter: filter,
            settingsManager: SettingsManager.shared,
            assetTransferAggregationFactory: assetTransferAggregationFactory,
            assetSufficiencyProvider: AssetExchangeSufficiencyProvider(),
            logger: Logger.shared
        )

        let presenter = GiftAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: GiftAssetOperationWireframe(
                stateObservable: stateObservable,
                buyTokensClosure: buyTokensClosure,
                transferCompletion: transferCompletion
            )
        )

        interactor.presenter = presenter

        return presenter
    }

    static func createSendPresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?,
        buyTokensClosure: BuyTokensClosure?
    ) -> SendAssetOperationPresenter {
        let filter = AssetOperationChainAssetFilterFactory.createSendAssetFilter(using: stateObservable.state.value)

        let interactor = SendAssetsOperationInteractor(
            stateObservable: stateObservable,
            filter: filter,
            settingsManager: SettingsManager.shared,
            logger: Logger.shared
        )

        let presenter = SendAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: SendAssetOperationWireframe(
                stateObservable: stateObservable,
                buyTokensClosure: buyTokensClosure,
                transferCompletion: transferCompletion
            )
        )

        interactor.presenter = presenter

        return presenter
    }

    static func createReceivePresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) -> ReceiveAssetOperationPresenter {
        let filter = AssetOperationChainAssetFilterFactory.createReceiveAssetFilter()

        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: filter,
            settingsManager: SettingsManager.shared,
            logger: Logger.shared
        )

        let presenter = ReceiveAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedAccount: wallet,
            wireframe: ReceiveAssetOperationWireframe(stateObservable: stateObservable)
        )

        interactor.presenter = presenter

        return presenter
    }

    static func createRampPresenter(
        dependencies: RampPresenterDependencies,
        flowStartingDelegate: RampFlowStartingDelegate?
    ) -> RampAssetOperationPresenter {
        let filter: ChainAssetsFilter = AssetOperationChainAssetFilterFactory.createRampAssetFilter(using: dependencies)

        let interactor = AssetsSearchInteractor(
            stateObservable: dependencies.stateObservable,
            filter: filter,
            settingsManager: SettingsManager.shared,
            logger: Logger.shared
        )

        let presenter = RampAssetOperationPresenter(
            interactor: interactor,
            viewModelFactory: dependencies.viewModelFactory,
            selectedAccount: dependencies.selectedAccount,
            rampProvider: dependencies.rampProvider,
            rampType: dependencies.rampType,
            wireframe: dependencies.wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.rampFlowStartingDelegate = flowStartingDelegate
        interactor.presenter = presenter

        return presenter
    }
}

extension AssetOperationViewFactory {
    struct RampPresenterDependencies {
        let stateObservable: AssetListModelObservable
        let selectedAccount: MetaAccountModel
        let rampProvider: RampProviderProtocol
        let rampType: RampActionType
        let currencyManager: CurrencyManager
        let viewModelFactory: AssetListAssetViewModelFactoryProtocol
        let wireframe: RampAssetOperationWireframeProtocol
    }
}

enum AssetOperationChainAssetFilterFactory {
    static func createGiftAssetFilter() -> ChainAssetsFilter {
        createReceiveAssetFilter()
    }

    static func createSendAssetFilter(using assetList: AssetListModel) -> ChainAssetsFilter {
        { chainAsset in
            let assetMapper = CustomAssetMapper(type: chainAsset.asset.type, typeExtras: chainAsset.asset.typeExtras)

            guard let transfersEnabled = try? assetMapper.transfersEnabled(), transfersEnabled else {
                return false
            }
            guard let balance = try? assetList.balances[chainAsset.chainAssetId]?.get() else {
                return false
            }

            return balance.transferable > 0
        }
    }

    static func createReceiveAssetFilter() -> ChainAssetsFilter {
        { $0.chain.syncMode.enabled() }
    }

    static func createRampAssetFilter(
        using dependencies: AssetOperationViewFactory.RampPresenterDependencies
    ) -> ChainAssetsFilter {
        { chainAsset in
            guard
                chainAsset.chain.syncMode.enabled(),
                let accountId = dependencies.selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId
            else {
                return false
            }

            let rampActions = dependencies.rampProvider.buildRampActions(
                for: chainAsset,
                accountId: accountId
            ).filter { $0.type == dependencies.rampType }

            return !rampActions.isEmpty
        }
    }
}
