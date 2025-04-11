import Foundation
import Foundation_iOS
import Keystore_iOS

enum AssetOperationViewFactory {
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
        case .offRamp: .init { R.string.localizable.assetOperationSellTitle(preferredLanguages: $0.rLanguages) }
        case .onRamp: .init { R.string.localizable.assetOperationBuyTitle(preferredLanguages: $0.rLanguages) }
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
            R.string.localizable.assetOperationReceiveTitle(preferredLanguages: $0.rLanguages)
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
            R.string.localizable.assetOperationSendTitle(preferredLanguages: $0.rLanguages)
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

    private static func createSendPresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        transferCompletion: TransferCompletionClosure?,
        buyTokensClosure: BuyTokensClosure?
    ) -> SendAssetOperationPresenter {
        let interactor = SendAssetsOperationInteractor(
            stateObservable: stateObservable,
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

    private static func createReceivePresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) -> ReceiveAssetOperationPresenter {
        let interactor = AssetsSearchInteractor(
            stateObservable: stateObservable,
            filter: { $0.chain.syncMode.enabled() },
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

    private static func createRampPresenter(
        dependencies: RampPresenterDependencies,
        flowStartingDelegate: RampFlowStartingDelegate?
    ) -> RampAssetOperationPresenter {
        let filter: ChainAssetsFilter = { chainAsset in
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

private extension AssetOperationViewFactory {
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
